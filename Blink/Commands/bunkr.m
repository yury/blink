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
#include "BlinkPaths.h"
#include "bk_getopts.h"
#include "xcall.h"
#import <AVFoundation/AVFoundation.h>
#import "MCPSession.h"

void _store_key(NSDictionary *key) {
  if (!key) {
    return;
  }
  
  NSString *path = [BlinkPaths.blink stringByAppendingPathComponent:@"bunkr.keys"];
  
  NSData *data = [NSData dataWithContentsOfFile:path];
  NSMutableDictionary *keysJSON;
  NSMutableArray *keysList;
  if (data) {
    keysJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if (!keysJSON) {
      keysJSON = [[NSMutableDictionary alloc] init];
    }
    keysList = [[NSMutableArray alloc] init];
    id keys = keysJSON[@"keys"];
    if (keys && [keys isKindOfClass: [NSMutableArray class]]) {
      keysList = keys;
    }
  } else {
    keysJSON = [[NSMutableDictionary alloc] init];
    keysList = [[NSMutableArray alloc] init];
  }
  
  [keysList addObject:key];
  keysJSON[@"keys"] = keysList;
  
  data = [NSJSONSerialization dataWithJSONObject:keysJSON options:kNilOptions error:nil];
  [data writeToFile:path atomically:YES];
}

NSArray *bunkrLoadKeys() {
  NSString *path = [BlinkPaths.blink stringByAppendingPathComponent:@"bunkr.keys"];
  
  NSData *data = [NSData dataWithContentsOfFile:path];
  if (!data) {
    return @[];
  }
  
  NSMutableDictionary *keysJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
  if (!keysJSON) {
    keysJSON = [[NSMutableDictionary alloc] init];
  }
  NSMutableArray *keysList = [[NSMutableArray alloc] init];
  id keys = keysJSON[@"keys"];
  if (keys && [keys isKindOfClass: [NSMutableArray class]]) {
    keysList = keys;
  }
  return keysList;
}

NSDictionary *bunkrKeyForId(NSString *fileIDAndCapId) {
  if (!fileIDAndCapId) {
    return nil;
  }
  
  NSArray *parts = [fileIDAndCapId componentsSeparatedByString:@":"];
  NSString *fileId = parts[0];
  NSString *capId = parts[1];
  
  NSString *path = [BlinkPaths.blink stringByAppendingPathComponent:@"bunkr.keys"];
  NSData *data = [NSData dataWithContentsOfFile:path];
  NSMutableDictionary *keysJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
  if (!keysJSON) {
    keysJSON = [[NSMutableDictionary alloc] init];
  }
  NSMutableArray *keysList = [[NSMutableArray alloc] init];
  id keys = keysJSON[@"keys"];
  if (keys && [keys isKindOfClass: [NSMutableArray class]]) {
    keysList = keys;
  }
  
  for (NSDictionary *key in keysList) {
    if ([fileId isEqualToString:key[@"fileID"]] && [capId isEqualToString:key[@"capID"]]) {
      return key;
    }
  }
  return nil;
}

NSData *bunkr_sign(NSString *fileID, NSString *capID, NSData *data, NSString *alg) {
  BlinkXCall *call = [[BlinkXCall alloc] init];
  NSURLComponents *comps = [NSURLComponents componentsWithString:@"bunkr://x-callback-url/sign-ssh"];
  
  comps.queryItems = @[
                       [NSURLQueryItem queryItemWithName:@"x-source" value:@"Blink"],
                       [NSURLQueryItem queryItemWithName:@"fileID" value:fileID],
                       [NSURLQueryItem queryItemWithName:@"capID" value:capID],
                       [NSURLQueryItem queryItemWithName:@"b64data" value:[data base64EncodedStringWithOptions:kNilOptions]],
                       [NSURLQueryItem queryItemWithName:@"alg" value:alg],
                       ];
  
  call.xURL = comps.URL;
  NSLog(@"url: %@", call.xURL.absoluteString);

  int result = [call execute];
  if (result == 0) {
    NSString *b64sign = call.resultParams[@"b64signature"];
    if (!b64sign) {
      return nil;
    }
    
    return [[NSData alloc] initWithBase64EncodedString:b64sign options:kNilOptions];
  }
  
  
  return nil;
}


int bunkr_main(int argc, char *argv[]) {
  thread_optind = 1;
  
  BlinkXCall *call = [[BlinkXCall alloc] init];
  call.xURL = [NSURL URLWithString:@"bunkr://x-callback-url/get-pubkey?x-source=Blink.app&infoTitle=Blink.app+Request+Key&infoDescription=Select+a+key+Bunkr+will+sign+operations+with"];
  
  int result = [call execute];
  if (result == 0) {
    puts("success");
    NSString * output = [NSString stringWithFormat:@"fileID: %@\npubkey: %@", call.resultParams[@"fileID"], call.resultParams[@"b64pubkey"]];
    NSDictionary *key = @{
      @"b64pubkey": call.resultParams[@"b64pubkey"] ?: NSNull.null,
      @"fileID": call.resultParams[@"fileID"] ?: NSNull.null,
      @"capID": call.resultParams[@"capID"] ?: NSNull.null
      };
    _store_key(key);
    puts(output.UTF8String);
  } else if (result == -1) {
    puts("error");
  } else if (result == -2) {
    puts("canceled");
  }
  
  return 0;
}


