////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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

#include <stdio.h>
#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "bk_getopts.h"
#include "xcall.h"
#import <AVFoundation/AVFoundation.h>
#import "MCPSession.h"


int bunkr_main(int argc, char *argv[]) {
  thread_optind = 1;
  
  BlinkXCall *call = [[BlinkXCall alloc] init];
  call.xURL = [NSURL URLWithString:@"bunkr://x-callback-url/get-pubkey?x-source=Blink.app&infoTitle=Blink.app+Request+Key&infoDescription=Select+a+key+Bunkr+will+sign+operations+with"];
  
  int result = [call execute];
  if (result == 0) {
    puts("success");
    NSString * output = [NSString stringWithFormat:@"fileID: %@\npubkey: %@", call.resultParams[@"fileID"], call.resultParams[@"b64pubkey"]];
    puts(output.UTF8String);
  } else if (result == -1) {
    puts("error");
  } else if (result == -2) {
    puts("canceled");
  }
  
  return 0;
}

