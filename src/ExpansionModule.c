/*
 Memory map:
 POKEY1            $0450    $045F     16 bytes
 POKEY2*           $0460    $046F     16 bytes
 XCTRL             $0470    $047F     1 byte
 RAM               $4000    $7FFF     16384 bytes
XCTRL Bit Description
+-------------------------------+
| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
+-------------------------------+
  |   |   |   |   |   |   |   |
  |   |   |   |   |   |   |   +-- Bank select bit 0 \
  |   |   |   |   |   |   +------ Bank select bit 1  | Totally 128 KByte in 16 KByte banks
  |   |   |   |   |   +---------- Bank select bit 3 /
  |   |   |   |   +-------------- Enable memory bit (1 = Memory enabled, 0 after power on)
  |   |   |   +------------------ Enable POKEY bit** (1 = POKEY enabled, 0 after power on)
  |   |   |
 NA  NA  NA = Not Available or Not Used
* = Can be mounted piggy back on the first POKEY. Description how to do this will come when i have tried it out.
** This bit controls both POKEY chip select signals.
The mapping is totally non compatible with pretty much everything. 
There is a bank select latch located at $0470 and the POKEY is located at $0450 
(There's also a chip select output ($0460) on the PLD which alows you to simply piggy back a second POKEY). 
Since the PLD is reconfigurable I could map the POKEY (or the RAM for that matter) to pretty much anything 
if you wanted to. However since the PLD is soldered under the POKEY this needs to be configured before delivery.
*/

#include <stdint.h>
#include <stdbool.h>

#include "ExpansionModule.h"

uint8_t xm_ram[XM_RAM_SIZE] = {0};
uint8_t xm_reg = 0;
uint8_t xm_bank = 0;
bool xm_pokey_enabled = false;
bool xm_mem_enabled = false;

void xm_Reset(void) {
    for (int i = 0; i < XM_RAM_SIZE; i++) {
        xm_ram[i] = 0;
    }
    xm_bank = 0;
    xm_reg = 0;
    xm_pokey_enabled = false;
    xm_mem_enabled = false;
}

uint8_t xm_Read(uint16_t address) {
    if (xm_pokey_enabled && (address >= 0x0450 && address < 0x0460)) {
        uint8_t b = pokey_GetRegister(0x4000 + (address - 0x0450));
        return b;
    }
    else if (xm_pokey_enabled && (address >= 0x0460 && address < 0x0470)) {
        uint8_t b = pokey_GetRegister(0x4000 + (address - 0x0460));
        return b;
    }
    else if (xm_mem_enabled && (address >= 0x4000 && address < 0x8000)) {
        uint8_t b = xm_ram[(xm_bank * 0x4000) + (address - 0x4000)];
        return b;
    }
    else if (address >= 0x0470 && address < 0x0480) {
        // TODO: Should the value be returned?
    }
    return 0;
}

void xm_Write(uint16_t address, uint8_t data) {
    if (xm_pokey_enabled && (address >= 0x0450 && address < 0x0460)) {
        pokey_SetRegister(0x4000 + (address - 0x0450), data);
    }
    else if (xm_pokey_enabled && (address >= 0x0460 && address < 0x0470)) {
        pokey_SetRegister(0x4000 + (address - 0x0460), data);
    }
    else if (xm_mem_enabled && (address >= 0x4000 && address < 0x8000)) {
        xm_ram[(xm_bank * 0x4000) + (address - 0x4000)] = data;
    }
    else if (address >= 0x0470 && address < 0x0480) {
        xm_reg = data;
        xm_bank = xm_reg & 7;
        xm_pokey_enabled = (xm_reg & 0x10) > 0;
        xm_mem_enabled = (xm_reg & 0x08) > 0;
    } 
}
