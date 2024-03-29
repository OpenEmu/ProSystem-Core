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
// Maria.h
// ----------------------------------------------------------------------------
#ifndef MARIA_H
#define MARIA_H

#define MARIA_SURFACE_SIZE 93440

#include "Equates.h"
#include "Pair.h"
#include "Memory.h"
#include "Rect.h"
#include "Sally.h"

extern void maria_Reset(void);
extern uint32_t maria_RenderScanline(void);
extern void maria_Clear(void);
extern rect maria_displayArea;
extern rect maria_visibleArea;
extern uint8_t maria_surface[MARIA_SURFACE_SIZE];
extern uint16_t maria_scanline;

#endif
