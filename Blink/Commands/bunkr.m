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
#import "BKPubKey.h"

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

int bunkr_genkey(NSString *bunkrSchema, NSString *keyName) {
  Pki * pki = [[Pki alloc] initWithType:BK_KEYTYPE_ECDSA andBits:256];
  NSString *privateKey = pki.privateKey;
  NSString *publicKey = [pki publicKeyWithComment:keyName];
  
  return 0;
}

int bunkr_linkkey(NSString *bunkrSchema, NSString *keyName) {
  
  BlinkXCall *call = [[BlinkXCall alloc] init];
  NSString *urlStr = [NSString stringWithFormat:@"%@://x-callback-url/get-pubkey?x-source=Blink.app&infoTitle=Blink.app+Request+Key&infoDescription=Select+a+key+Bunkr+will+sign+operations+with", bunkrSchema];
  call.xURL = [NSURL URLWithString:urlStr];
  
  int result = [call execute];
  if (result == 0) {
    puts("success");
    
    NSString *b64pubkey = call.resultParams[@"b64pubkey"];
    if (!b64pubkey) {
      puts("no public key");
      return -1;
    }
    NSData * pubKeyData = [[NSData alloc] initWithBase64EncodedString:b64pubkey options:kNilOptions];
    NSString * pubKey = [[NSString alloc] initWithData:pubKeyData encoding:NSUTF8StringEncoding];
    
    if (!pubKey) {
      puts("invalid public key");
      return -1;
    }
    
    NSDictionary *key = @{
                          @"fileID": call.resultParams[@"fileID"] ?: NSNull.null,
                          @"capID": call.resultParams[@"capID"] ?: NSNull.null,
                          @"env": call.resultParams[@"env"] ?: NSNull.null
                          };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:key options:kNilOptions error:nil];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [BKPubKey saveBunkrCard:keyName publicKey:pubKey bunkrJSON:jsonStr];
    
    NSUInteger count = [BKPubKey bunkrKeys].count;
    NSString * output = [NSString stringWithFormat:@"fileID: %@\npubkey: %@. count: %@", call.resultParams[@"fileID"], b64pubkey, @(count)];
    puts(output.UTF8String);
  } else if (result == -1) {
    puts("error");
  } else if (result == -2) {
    puts("canceled");
  }
  
  return 0;
}

int bunkr_main(int argc, char *argv[]) {
  NSString *bunkrSchema = @(argv[0]);
  
  thread_optind = 1;
  
  NSString *usage = [@[
                      @"Usage: bunkr linkkey <name>",
                      @"       bunkr genkey <name>"
                      ] componentsJoinedByString:@"\n"];;
  
  if (argc <= 2) {
    puts(usage.UTF8String);
    return -1;
  }
  
  NSString *command = @(argv[1]);
  NSString *keyName = @(argv[2]);
  
  if ([@"linkkey" isEqual:command]) {
    return bunkr_linkkey(bunkrSchema, keyName);
  } else if ([@"linkkey" isEqual:command]) {
    return bunkr_genkey(bunkrSchema, keyName);
  }
  
  puts(usage.UTF8String);
  
  return -1;
}


