//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


#import "SSHAgent.h"

static uint32_t _agent_get_u32(const void *vp) {
  const uint8_t *p = (const uint8_t *)vp;
  uint32_t v;
  
  v  = (uint32_t)p[0] << 24;
  v |= (uint32_t)p[1] << 16;
  v |= (uint32_t)p[2] << 8;
  v |= (uint32_t)p[3];
  
  return v;
}

static void _agent_put_u32(void *vp, uint32_t v) {
  uint8_t *p = (uint8_t *)vp;
  
  p[0] = (uint8_t)(v >> 24) & 0xff;
  p[1] = (uint8_t)(v >> 16) & 0xff;
  p[2] = (uint8_t)(v >> 8) & 0xff;
  p[3] = (uint8_t)v & 0xff;
}



@implementation SSHAgent

- (int)processMessage:(NSString *)msg {
  if (msg.length < 5) {
    return 0; // Incomplete message header
  }
  
  return 0;
}

@end
