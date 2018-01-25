////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#import "TermController.h"
#import "BKDefaults.h"
#import "BKSettingsNotifications.h"
#import "MCPSession.h"
#import "Session.h"
#import "StateManager.h"
#import "TermDevice.h"

NSString * const BKUserActivityTypeCommandLine = @"com.blink.cmdline";
NSString * const BKUserActivityCommandLineKey = @"com.blink.cmdline.key";


@interface TermController () <TerminalDelegate, SessionDelegate>
@end

@implementation TermController {
  MCPSession *_session;
  NSDictionary *_activityUserInfo;
  BOOL _isReloading;
  TermDevice *_termDevice;
}

- (void)loadView
{
  [super loadView];
  
  if (_sessionStateKey == nil) {
    _sessionStateKey = [[NSProcessInfo processInfo] globallyUniqueString];
  }
  
  _termView = [[TermView alloc] initWithFrame:self.view.frame];
  _termView.restorationIdentifier = @"TermView";
  _termView.termDelegate = self;
  
  self.view = _termView;
}

- (NSString *)title {
  return _termView.title;
}

- (void)write:(NSString *)input
{
  // Trasform the string and write it, with the correct sequence
  // TODO: Write to the device, and let it handle whatever it has to handle in the right encoding, etc...
  [_termDevice write: input];
}

- (void)indexCommand:(NSString *)cmdLine {
  
  NSUserActivity * activity = [[NSUserActivity alloc] initWithActivityType:BKUserActivityTypeCommandLine];
  activity.eligibleForPublicIndexing = NO;
  activity.eligibleForSearch = YES;
  activity.eligibleForHandoff = YES;
  
  
  _activityKey = [NSString stringWithFormat:@"run: %@ ", cmdLine];
  [activity setTitle:_activityKey];
  
  _activityUserInfo = @{BKUserActivityCommandLineKey: cmdLine ?: @"help"};
  
  activity.userInfo = _activityUserInfo;
  
  self.userActivity = activity;
  [self.userActivity becomeCurrent];
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
  [activity setTitle:_activityKey];
  [activity addUserInfoEntriesFromDictionary:_activityUserInfo];
  activity.keywords = [NSSet setWithArray:@[@"blink", @"shell", @"mosh", @"ssh", @"terminal", @"remote"]];
  
  [activity setRequiredUserInfoKeys:[NSSet setWithArray:_activityUserInfo.allKeys]];
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
  if (![activity.activityType isEqualToString: BKUserActivityTypeCommandLine]) {
    [super restoreUserActivityState:activity];
  }
  
  NSString *cmdLine = [activity.userInfo objectForKey:BKUserActivityCommandLineKey];
  if (cmdLine) {
    // TODO: investigate lost first char on iPad
    [self write:[NSString stringWithFormat:@" %@\n", cmdLine]];
  }
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if (_sessionParameters == nil) {
    [self _initSessionParameters];
  }

  [_termView loadWith:_sessionParameters];
}

- (void)_initSessionParameters
{
  _sessionParameters = [[MCPSessionParameters alloc] init];
  _sessionParameters.fontSize = [[BKDefaults selectedFontSize] integerValue];
  _sessionParameters.fontName = [BKDefaults selectedFontName];
  _sessionParameters.themeName = [BKDefaults selectedThemeName];
}

- (void)_startSession
{
  _termDevice = [[TermDevice alloc] init];
  _termDevice.control = self;

  _session = [[MCPSession alloc] initWithStream:_termDevice.stream andParametes:_sessionParameters];
  _session.delegate = self;
  [_session executeWithArgs:@""];
}

- (void)setRawMode:(BOOL)raw
{
  _rawMode = raw;
  _termInput.raw = raw;
}

- (void)updateTermRows:(NSNumber *)rows Cols:(NSNumber *)cols
{
  _sessionParameters.rows = rows.shortValue;
  _sessionParameters.cols = cols.shortValue;
  
  _termDevice.stream.sz->ws_row = rows.shortValue;
  _termDevice.stream.sz->ws_col = cols.shortValue;
  
  if ([self.delegate respondsToSelector:@selector(terminalDidResize:)]) {
    [self.delegate terminalDidResize:self];
  }
  [_session sigwinch];
}

- (void)fontSizeChanged:(NSNumber *)newSize
{
  _sessionParameters.fontSize = [newSize integerValue];
}

- (void)terminalIsReady: (NSDictionary *)size
{
  _sessionParameters.rows = [size[@"rows"] integerValue];
  _sessionParameters.cols = [size[@"cols"] integerValue];
  
  [self _startSession];
  if (self.userActivity) {
    [self restoreUserActivityState:self.userActivity];
  }
}

- (void)dealloc
{
  _termDevice = nil;
  [self.userActivity resignCurrent];
}

#pragma mark SessionDelegate

- (void)sessionFinished
{
  if (_isReloading) {
    _isReloading = NO;
    [self _initSessionParameters];
    [_termView reloadWith:_sessionParameters];
  } else {
    [_delegate terminalHangup:self];
  }
  _termDevice = nil;
}

#pragma mark Notifications


- (void)terminate
{
  [_termView terminate];
  [_session kill];
}

- (void)reload
{
  _sessionParameters.childSessionType = nil;
  _sessionParameters.childSessionParameters =  nil;
  _isReloading = YES;
}

- (void)suspend
{
  [_session suspend];
}

- (void)resume
{
  [self _startSession];
}

- (void)focus {
  [_termView focus];
  if (![_termView.window isKeyWindow]) {
    [_termView.window makeKeyWindow];
  }
  if (![_termInput isFirstResponder]) {
    [_termInput becomeFirstResponder];
  }
}

- (void)blur {
  [_termView blur];
}

- (void)attachInput:(TermInput *)termInput
{
  _termInput = termInput;
  if (!termInput) {
    [_termView blur];
  }
  
  if (_termInput.termDelegate != self) {
    [_termInput.termDelegate attachInput:nil];
  }
  
  _termInput.raw = _rawMode;
  _termInput.termDelegate = self;
  
  if ([_termInput isFirstResponder]) {
    [_termView focus];
  } else {
    [_termView blur];
  }
}



@end
