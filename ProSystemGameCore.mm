/*
 Copyright (c) 2013, OpenEmu Team


 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ProSystemGameCore.h"
#import "OE7800SystemResponderClient.h"

#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>

#include "ProSystem.h"
#include "Database.h"
#include "Sound.h"
#include "Palette.h"
#include "Maria.h"
#include "Tia.h"
#include "Pokey.h"
#include "Cartridge.h"

@interface ProSystemGameCore () <OE7800SystemResponderClient>
{
    uint32_t *_videoBuffer;
    uint32_t _displayPalette[256];
    uint8_t  *_soundBuffer;
    uint8_t _inputState[17];
    int _videoWidth, _videoHeight;
}
- (void)setPalette32;
@end

@implementation ProSystemGameCore

- (id)init
{
    if((self = [super init]))
    {
        _videoBuffer = (uint32_t *)malloc(320 * 292 * 4);
        _soundBuffer = (uint8_t *)malloc(8192);
        _videoWidth  = 320;
        _videoHeight = 240;
    }

    return self;
}

- (void)dealloc
{
    free(_videoBuffer);
    free(_soundBuffer);
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    memset(_inputState, 0, sizeof(_inputState));

    // Difficulty switches: Left position = (B)eginner, Right position = (A)dvanced
    // Left difficulty switch defaults to left position, "(B)eginner"
    _inputState[15] = 1;

    // Right difficulty switch defaults to right position, "(A)dvanced", which fixes Tower Toppler
    _inputState[16] = 0;

    if(cartridge_Load([path UTF8String]))
    {
        NSString *databasePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"ProSystem.dat"];
        database_filename = [databasePath UTF8String];
        database_enabled = true;

        // BIOS is optional
        NSString *biosROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"7800 BIOS (U).rom"];
        if (bios_Load([biosROM UTF8String]))
		    bios_enabled = true;

        NSLog(@"Headerless MD5 hash: %s", cartridge_digest.c_str());
        NSLog(@"Header info (often wrong):\ntitle: %s\ntype: %d\nregion: %s\npokey: %s", cartridge_title.c_str(), cartridge_type, cartridge_region == REGION_NTSC ? "NTSC" : "PAL", cartridge_pokey ? "true" : "false");

	    database_Load(cartridge_digest);
	    prosystem_Reset();

        std::string title = common_Trim(cartridge_title);
        NSLog(@"Database info:\ntitle: %@\ntype: %d\nregion: %s\npokey: %s", [NSString stringWithUTF8String:title.c_str()], cartridge_type, cartridge_region == REGION_NTSC ? "NTSC" : "PAL", cartridge_pokey ? "true" : "false");

        //sound_SetSampleRate(48000);
        [self setPalette32];

        return YES;
    }

    return NO;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
	prosystem_ExecuteFrame(_inputState);

    _videoWidth  = maria_visibleArea.GetLength();
    _videoHeight = maria_visibleArea.GetHeight();

    uint8_t *buffer = maria_surface + ((maria_visibleArea.top - maria_displayArea.top) * maria_visibleArea.GetLength());
    uint32_t *surface = (uint32_t *)_videoBuffer;
    int pitch = 320;

    for(int indexY = 0; indexY < _videoHeight; indexY++)
    {
        for(int indexX = 0; indexX < _videoWidth; indexX += 4)
        {
            surface[indexX + 0] = _displayPalette[buffer[indexX + 0]];
            surface[indexX + 1] = _displayPalette[buffer[indexX + 1]];
            surface[indexX + 2] = _displayPalette[buffer[indexX + 2]];
            surface[indexX + 3] = _displayPalette[buffer[indexX + 3]];
        }
        surface += pitch;
        buffer += _videoWidth;
    }

    int length = sound_Store(_soundBuffer);
    [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:length];
}

- (void)resetEmulation
{
    prosystem_Reset();
}

- (NSTimeInterval)frameInterval
{
    return cartridge_region == REGION_NTSC ? 60 : 50;
}

#pragma mark - Video

- (const void *)videoBuffer
{
    return _videoBuffer;
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, _videoWidth, _videoHeight);
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(320, 292);
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_INT_8_8_8_8_REV;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB8;
}

#pragma mark - Audio

- (double)audioSampleRate
{
    return 48000;
}

- (NSUInteger)channelCount
{
    return 1;
}

- (NSUInteger)audioBitDepth
{
    return 8;
}

#pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    return prosystem_Save([fileName UTF8String], false) ? YES : NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return prosystem_Load([fileName UTF8String]) ? YES : NO;
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    size_t length = cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM ? 32837 : 16453;
    void *bytes = malloc(length);

    if(prosystem_Save_buffer((uint8_t *)bytes))
    {
        return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];
    }
    else
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreCouldNotSaveStateError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                   NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                   }];
        }

        return nil;
    }
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    size_t serial_size = cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM ? 32837 : 16453;
    if(serial_size != [state length])
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreStateHasWrongSizeError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                                                   NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
                                                   }];
        }
        return NO;
    }

    if(prosystem_Load_buffer((uint8_t *)[state bytes]))
    {
        return YES;
    }
    else
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreCouldNotLoadStateError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"The save state data could not be read"
                                                   }];
        }

        return NO;
    }
}

#pragma mark - Input
// ----------------------------------------------------------------------------
// SetInput
// +----------+--------------+-------------------------------------------------
// | Offset   | Controller   | Control
// +----------+--------------+-------------------------------------------------
// | 00       | Joystick 1   | Right
// | 01       | Joystick 1   | Left
// | 02       | Joystick 1   | Down
// | 03       | Joystick 1   | Up
// | 04       | Joystick 1   | Button 1
// | 05       | Joystick 1   | Button 2
// | 06       | Joystick 2   | Right
// | 07       | Joystick 2   | Left
// | 08       | Joystick 2   | Down
// | 09       | Joystick 2   | Up
// | 10       | Joystick 2   | Button 1
// | 11       | Joystick 2   | Button 2
// | 12       | Console      | Reset
// | 13       | Console      | Select
// | 14       | Console      | Pause
// | 15       | Console      | Left Difficulty
// | 16       | Console      | Right Difficulty
// +----------+--------------+-------------------------------------------------
const int ProSystemMap[] = { 3, 2, 1, 0, 4, 5, 9, 8, 7, 6, 10, 11, 13, 14, 12, 15, 16};
- (oneway void)didPush7800Button:(OE7800Button)button forPlayer:(NSUInteger)player;
{
    int playerShift = player != 1 ? 6 : 0;

    switch(button)
    {
        case OE7800ButtonUp:
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            _inputState[ProSystemMap[button + playerShift]] = 1;
            break;

        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            _inputState[ProSystemMap[button + 6]] = 1;
            break;

        case OE7800ButtonLeftDiff:
        case OE7800ButtonRightDiff:
            _inputState[ProSystemMap[button + 6]] ^= (1 << 0);
            break;

        default:
            break;
    }
}

- (oneway void)didRelease7800Button:(OE7800Button)button forPlayer:(NSUInteger)player;
{
    int playerShift = player != 1 ? 6 : 0;

    switch(button)
    {
        case OE7800ButtonUp:
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            _inputState[ProSystemMap[button + playerShift]] = 0;
            break;

        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            _inputState[ProSystemMap[button + 6]] = 0;
            break;

        default:
            break;
    }
}

#pragma mark - Misc Helper Methods
// Set palette 32bpp
- (void)setPalette32
{
    for(int index = 0; index < 256; index++)
    {
        uint32_t r = palette_data[(index * 3) + 0] << 16;
        uint32_t g = palette_data[(index * 3) + 1] << 8;
        uint32_t b = palette_data[(index * 3) + 2];
        _displayPalette[index] = r | g | b;
    }
}

@end
