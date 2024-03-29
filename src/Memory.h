// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _      __  ___
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /      / / _
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /   ___/ /__/
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// Copyright 2020 Rupert Carmichael
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Memory.h
// ----------------------------------------------------------------------------
#ifndef MEMORY_H
#define MEMORY_H

#include "Equates.h"
#include "Bios.h"
#include "Cartridge.h"
#include "Tia.h"
#include "Riot.h"

#define MEMORY_SIZE 65536

extern void memory_Reset(void);
extern uint8_t memory_Read(uint16_t address);
extern void memory_Write(uint16_t address, uint8_t data);
extern void memory_WriteROM(uint16_t address, uint32_t size, const uint8_t* data);
extern void memory_ClearROM(uint16_t address, uint32_t size);
extern uint8_t memory_ram[MEMORY_SIZE];
extern uint8_t memory_rom[MEMORY_SIZE];

#endif
