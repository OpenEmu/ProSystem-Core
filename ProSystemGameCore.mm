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
    uint32_t *videoBuffer;
    uint8_t  *soundBuffer;
    int videoWidth, videoHeight;
    uint display_palette32[256];
    byte keyboard_data[17];
}
@end

ProSystemGameCore *current;
@implementation ProSystemGameCore

static void display_ResetPalette32( ) {
    for(uint index = 0; index < 256; index++) {
        uint r = palette_data[(index * 3) + 0] << 16;
        uint g = palette_data[(index * 3) + 1] << 8;
        uint b = palette_data[(index * 3) + 2];
        current->display_palette32[index] = r | g | b;
    }
}

- (id)init
{
    if((self = [super init]))
    {
        videoBuffer = (uint32_t *)malloc(320 * 292 * 4);
        soundBuffer = (uint8_t *)malloc(8192);
        videoWidth  = 320;
        videoHeight = 240;
        current = self;
    }
    
    return self;
}

- (void)dealloc
{
    free(videoBuffer);
    free(soundBuffer);
}

#pragma mark Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    memset(keyboard_data, 0, sizeof(keyboard_data));
    
    // Difficulty switches: Left position = (B)eginner, Right position = (A)dvanced
    // Left difficulty switch defaults to left position, "(B)eginner"
    keyboard_data[15] = 1;
    
    // Right difficulty switch defaults to right position, "(A)dvanced", which fixes Tower Toppler
    keyboard_data[16] = 0;
    
    if(cartridge_Load([path UTF8String])) {
	    //sound_Stop( );
	    //display_Clear( );
        
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
	    prosystem_Reset( );
        
        std::string title = common_Trim(cartridge_title);
        NSLog(@"Database info:\ntitle: %@\ntype: %d\nregion: %s\npokey: %s", [NSString stringWithUTF8String:title.c_str()], cartridge_type, cartridge_region == REGION_NTSC ? "NTSC" : "PAL", cartridge_pokey ? "true" : "false");
        
        //sound_SetSampleRate(48000);
	    //display_ResetPalette( );
        display_ResetPalette32( );
	    //console_SetZoom(display_zoom);
	    //sound_Play( );
        
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
	prosystem_ExecuteFrame(keyboard_data); //wants input
    
    current->videoWidth  = maria_visibleArea.GetLength();
    current->videoHeight = maria_visibleArea.GetHeight();
    
    const byte* buffer = maria_surface + ((maria_visibleArea.top - maria_displayArea.top) * maria_visibleArea.GetLength( ));
    
    uint* surface = (uint*)videoBuffer;
    //uint pitch = 320 >> 2; // should be Distance, in bytes, to the start of next line.
    uint pitch = 320;
    for(uint indexY = 0; indexY < current->videoHeight; indexY++) {
        for(uint indexX = 0; indexX < current->videoWidth; indexX += 4) {
            surface[indexX + 0] = display_palette32[buffer[indexX + 0]];
            surface[indexX + 1] = display_palette32[buffer[indexX + 1]];
            surface[indexX + 2] = display_palette32[buffer[indexX + 2]];
            surface[indexX + 3] = display_palette32[buffer[indexX + 3]];
        }
        surface += pitch;
        buffer += current->videoWidth;
    }

    int length = sound_Store(soundBuffer);
    [[current ringBufferAtIndex:0] write:soundBuffer maxLength:length];
}

- (void)resetEmulation
{
    prosystem_Reset();
}

#pragma mark Video

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, current->videoWidth, current->videoHeight);
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(320, 292);
}

- (const void *)videoBuffer
{
    return videoBuffer;
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

- (NSTimeInterval)frameInterval
{
    return cartridge_region == REGION_NTSC ? 60 : 50;
}

#pragma mark Audio

- (NSUInteger)channelCount
{
    return 1;
}

- (double)audioSampleRate
{
    return 48000;
}

- (NSUInteger)audioBitDepth
{
    return 8;
}

#pragma mark Input
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
    
    switch (button) {
        case OE7800ButtonUp:
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            keyboard_data[ProSystemMap[button + playerShift]] = 1;
            break;
        
        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            keyboard_data[ProSystemMap[button + 6]] = 1;
            break;
            
        case OE7800ButtonLeftDiff:
        case OE7800ButtonRightDiff:
            keyboard_data[ProSystemMap[button + 6]] ^= (1 << 0);
            break;
            
        default:
            break;
    }
}

- (oneway void)didRelease7800Button:(OE7800Button)button forPlayer:(NSUInteger)player;
{
    int playerShift = player != 1 ? 6 : 0;
    
    switch (button) {
        case OE7800ButtonUp:
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            keyboard_data[ProSystemMap[button + playerShift]] = 0;
            break;
            
        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            keyboard_data[ProSystemMap[button + 6]] = 0;
            break;
            
        default:
            break;
    }
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    return prosystem_Save([fileName UTF8String], false) ? YES : NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return prosystem_Load([fileName UTF8String]) ? YES : NO;
}

@end
