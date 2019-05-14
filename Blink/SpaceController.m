////////////////////////////////////////////////////////////////////////////////
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

#import "BKDefaults.h"
#import "SpaceController.h"
#import "BKSettingsNotifications.h"
#import "BKUserConfigurationManager.h"
#import "MBProgressHUD/MBProgressHUD.h"
#import "ScreenController.h"
#import "SmartKeysController.h"
#import "TermController.h"
#import "TermInput.h"
#import "MusicManager.h"
#import "TouchOverlay.h"
#import "BKTouchIDAuthManager.h"
#import "GeoManager.h"
#import "Blink-Swift.h"

@interface SpaceController () <
  UIDropInteractionDelegate,
  SplitViewControllerDelegate,
  TermControlDelegate,
  TouchOverlayDelegate,
  ControlPanelDelegate
>

@property (readonly) TermController *currentTerm;
@property (readonly) TermDevice *currentDevice;

@end

@implementation SpaceController {
  SplitViewController *_splitViewController;
  CollectionViewSplitLayout *_layout;
  LayoutNode *_rootNode;
  NSMutableArray *_ctrls;
  NSUInteger _currentCtrlIdx;
  NSMutableDictionary *_ctrlsMap;
  
  MBProgressHUD *_hud;
  MBProgressHUD *_musicHUD;
  
  TouchOverlay *_touchOverlay;

  NSMutableArray<UIKeyCommand *> *_kbdCommands;
  NSMutableArray<UIKeyCommand *> *_kbdCommandsWithoutDiscoverability;
  TermInput *_termInput;
  BOOL _unfocused;
  NSTimer *_activeTimer;
  NSTimer *_restoreLayoutTimer;
  CGFloat _proposedKBBottomInset;
  BOOL _active;
}

#pragma mark Setup

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  if (self.view.window.screen == UIScreen.mainScreen) {
    UIEdgeInsets insets =  UIEdgeInsetsMake(0, 0, _proposedKBBottomInset, 0);
    _touchOverlay.frame = UIEdgeInsetsInsetRect(self.view.bounds, insets);
  } else {
    _touchOverlay.frame = self.view.bounds;
  }
}

- (void)viewSafeAreaInsetsDidChange {
  [super viewSafeAreaInsetsDidChange];
  [self updateDeviceSafeMarings:self.view.safeAreaInsets];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _currentCtrlIdx = 0;
  
  _ctrls = [[NSMutableArray alloc] init];
  _ctrlsMap = [[NSMutableDictionary alloc] init];
  
  self.view.opaque = YES;
  
//  _rootNode = [[LayoutNode alloc] initWithKey: [LayoutNode genKey]];
  _rootNode = [[LayoutNode alloc] initWithKey:@"root"];
  
  CollectionViewSplitLayout *layout = [[CollectionViewSplitLayout alloc] initWithRoot:_rootNode];
  
  _splitViewController = [[SplitViewController alloc] initWithSplitLayout: layout];
  
  [self addChildViewController:_splitViewController];
    _splitViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  _splitViewController.view.frame = self.view.bounds;
  [self.view addSubview:_splitViewController.view];
  
   [_splitViewController didMoveToParentViewController:self];
  
  _splitViewController.splitViewDelegate = self;
  
  
  _touchOverlay = [[TouchOverlay alloc] initWithFrame:self.view.bounds];
  [self.view addSubview:_touchOverlay];
  _touchOverlay.touchDelegate = self;
  _touchOverlay.controlPanel.controlPanelDelegate = self;
//  [_touchOverlay attachPageViewController:_splitViewController];
  
  _termInput = [[TermInput alloc] init];
  [self.view addSubview:_termInput];
  [self registerForNotifications];

  [self setKbdCommands];
  if (_ctrls.count == 0) {
    [self _createShellWithUserActivity: nil sessionStateKey:nil animated:YES completion:nil];
  }
  
  if (@available(iOS 11.0, *)) {
    UIDropInteraction *catchDropInteraction = [[UIDropInteraction alloc] initWithDelegate:self];
    [self.view addInteraction:catchDropInteraction];
    
    UIDropInteraction *termInputDropInteraction = [[UIDropInteraction alloc] initWithDelegate:self];
    [_termInput addInteraction:termInputDropInteraction];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];

  if ([_termInput isFirstResponder]) {
    [self _attachInputToCurrentTerm];
    return;
  }

  if (!_unfocused) {
    [self _focusOnShell];
  }
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
  return YES;
}

- (void)_attachInputToCurrentTerm
{
  [self.currentDevice attachInput:_termInput];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder andStateManager: (StateManager *)stateManager
{
  UIColor * bgColor = [coder decodeObjectForKey:@"bgColor"] ?: [UIColor blackColor];
  _unfocused = [coder decodeBoolForKey:@"_unfocused"];
  NSArray *sessionStateKeys = [coder decodeObjectForKey:@"sessionStateKeys"];
  
  _ctrls = [[NSMutableArray alloc] init];
  
  for (NSString *sessionStateKey in sessionStateKeys) {
    TermController *term = [[TermController alloc] init];
    term.sessionStateKey = sessionStateKey;
    [stateManager restoreState:term];
    term.delegate = self;
    term.userActivity = nil;
    term.bgColor = bgColor;
    
    [_ctrls addObject:term];
  }
  
  NSInteger idx = [coder decodeIntegerForKey:@"idx"];
  _currentCtrlIdx = idx;
  TermController *term = _ctrls[idx];
  
  [self loadViewIfNeeded];
  self.view.backgroundColor = bgColor;
  
//  __weak typeof(self) weakSelf = self;
//  [_viewportsController setViewControllers:@[term]
//                                 direction:UIPageViewControllerNavigationDirectionForward
//                                  animated:NO
//                                completion:^(BOOL complete) {
//                                  if (complete) {
//                                    [weakSelf _attachInputToCurrentTerm];
//                                  }
//                                }];
  [self.view setNeedsLayout];
  [self.view layoutIfNeeded];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super encodeRestorableStateWithCoder:coder];
  NSMutableArray *sessionStateKeys = [[NSMutableArray alloc] init];
  
  for (TermController *term in _ctrls) {
    [sessionStateKeys addObject:term.sessionStateKey];
  }
  
  NSInteger idx = [_ctrls indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    idx = 0;
  }
  [coder encodeInteger:idx forKey:@"idx"];
  [coder encodeObject:sessionStateKeys forKey:@"sessionStateKeys"];
  [coder encodeBool:_unfocused forKey:@"_unfocused"];
  [coder encodeObject:self.view.backgroundColor forKey:@"bgColor"];
}

//applicationFinishedRestoringState

- (void)applicationFinishedRestoringState {
    if ([_termInput isFirstResponder]) {
      [self _attachInputToCurrentTerm];
      return;
    }
  
    if (!_unfocused) {
      [self _focusOnShell];
    }
}

- (void)registerForNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  
  [defaultCenter removeObserver:self];

  [defaultCenter addObserver:self
                    selector:@selector(_keyboardWillChangeFrame:)
                        name:UIKeyboardWillChangeFrameNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_appDidBecomeActive)
                        name:UIApplicationDidBecomeActiveNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_focusOnShell)
                        name:BKUserAuthenticated
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_appWillResignActive)
                        name:UIApplicationWillResignActiveNotification
                      object:nil];
  
  
  [defaultCenter addObserver:self
		    selector:@selector(keyboardFuncTriggerChanged:)
			name:BKKeyboardFuncTriggerChanged
		      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_onGeoLock)
                        name:BLGeoLockNotification
                      object:nil];
}

- (void)_appDidBecomeActive
{
  [_activeTimer invalidate];
  _activeTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(_delayedDidBecomeActive) userInfo:nil repeats:NO];
}

- (void)_delayedDidBecomeActive
{
  [_activeTimer invalidate];
  _activeTimer = nil;
  
  _active = YES;
  _restoreLayoutTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(_restoreLayoutAfterBecomeActive) userInfo:nil repeats:NO];
}

- (void)_restoreLayoutAfterBecomeActive {
  [_restoreLayoutTimer invalidate];
  _restoreLayoutTimer = nil;
  [self updateKbBottomSafeMargins:_proposedKBBottomInset];
  [self.view setNeedsLayout];
}

-(void)_appWillResignActive
{
  if (_activeTimer) {
    [_activeTimer invalidate];
    _activeTimer = nil;
    return;
  }
  
  if (_restoreLayoutTimer) {
    [_restoreLayoutTimer invalidate];
    _restoreLayoutTimer = nil;
  }
  
  _active = NO;
  _unfocused = ![_termInput isFirstResponder];
}

- (void)_focusOnShell
{
  _active = YES;
  [_termInput becomeFirstResponder];
  [self _attachInputToCurrentTerm];
}



#pragma mark Events

// The Space will be responsible to accommodate the work environment for widgets, adjusting the size, making sure it doesn't overlap content,
// moving widgets or scrolling to them when necessary, etc...
// In this case we make sure we take the SmartBar/Keys into account.
- (void)_keyboardWillChangeFrame:(NSNotification *)sender
{
  CGFloat bottomInset = 0;
  
  CGRect kbFrame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
//  NSTimeInterval duration = [sender.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  
  CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
  if (CGRectGetMaxY(kbFrame) >= viewHeight) {
    bottomInset = viewHeight - kbFrame.origin.y;
  }
  
  UIView *accessoryView = _termInput.inputAccessoryView;
  CGFloat accessoryHeight = accessoryView.frame.size.height;
  if (bottomInset > 80) {
    accessoryView.hidden = NO;
    _termInput.softwareKB = YES;
  } else if (bottomInset == accessoryHeight) {
    if (_touchOverlay.panGestureRecognizer.state == UIGestureRecognizerStateRecognized) {
      accessoryView.hidden = YES;
    } else {
      accessoryView.hidden = ![BKUserConfigurationManager userSettingsValueForKey:BKUserConfigShowSmartKeysWithXKeyBoard];
      _termInput.softwareKB = NO;
    }
  } else if (kbFrame.size.height == 0) { // Other screen kb
    accessoryView.hidden = YES;
  }
  
  if (accessoryView.hidden) {
    bottomInset -= accessoryHeight;
    if (bottomInset < 0) {
      bottomInset = 0;
    }
    _termInput.softwareKB = NO;
  }
  
  _proposedKBBottomInset = bottomInset;
  
  if (!_active) {
    [self.view setNeedsLayout];
    return;
  }
  [self updateKbBottomSafeMargins:bottomInset];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    for (TermController *term in previousViewControllers) {
      [term.termDevice attachInput:nil];
    }

    [self _displayHUD];
    [self _attachInputToCurrentTerm];
  }
}


#pragma mark Spaces
- (TermController *)currentTerm
{
  return _ctrls[_currentCtrlIdx];
}

- (TermDevice *)currentDevice
{
  return self.currentTerm.termDevice;
}

- (void)_toggleMusicHUD
{
  if (_musicHUD) {
    [_musicHUD hideAnimated:YES];
    _musicHUD = nil;
    return;
  }

  [_hud hideAnimated:NO];

  _musicHUD = [MBProgressHUD showHUDAddedTo:_touchOverlay animated:YES];
  _musicHUD.mode = MBProgressHUDModeCustomView;
  _musicHUD.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
  _musicHUD.bezelView.color = [UIColor clearColor];
  _musicHUD.contentColor = [UIColor whiteColor];

  _musicHUD.customView = [[MusicManager shared] hudView];
  
  UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_toggleMusicHUD)];
  [_musicHUD.backgroundView addGestureRecognizer:tapRecognizer];
}

- (void)_displayHUD
{
  if (_musicHUD) {
    [_musicHUD hideAnimated:YES];
    _musicHUD = nil;
    return;
  }
  
  if (_hud) {
    [_hud hideAnimated:NO];
  }
  
  TermController *currentTerm = self.currentTerm;
  
  if (currentTerm.view.backgroundColor && currentTerm.view.backgroundColor != [UIColor clearColor]) {
    self.view.backgroundColor = currentTerm.view.backgroundColor;
//    _viewportsController.view.backgroundColor = currentTerm.view.backgroundColor;
    _splitViewController.view.backgroundColor = currentTerm.view.backgroundColor;
    self.view.window.backgroundColor = currentTerm.view.backgroundColor;
  }

  _hud = [MBProgressHUD showHUDAddedTo:_touchOverlay animated:_hud == nil];
  _hud.mode = MBProgressHUDModeCustomView;
  _hud.bezelView.color = [UIColor darkGrayColor];
  _hud.contentColor = [UIColor whiteColor];
  _hud.userInteractionEnabled = NO;
  _hud.alpha = 0.6;
  
  UIPageControl *pages = [[UIPageControl alloc] init];
  pages.currentPageIndicatorTintColor = [UIColor cyanColor];
  pages.numberOfPages = [_ctrls count];
  pages.currentPage = [_ctrls indexOfObject:currentTerm];
  
  _hud.customView = pages;
  
  NSString *title = currentTerm.title.length ? currentTerm.title : @"blink";
  
  MCPSessionParameters *params = currentTerm.sessionParameters;
  if (params.rows == 0 && params.cols == 0) {
    _hud.label.numberOfLines = 1;
    _hud.label.text = title;
  } else {
    NSString *geometry =
      [NSString stringWithFormat:@"%ld x %ld", (long)params.rows, (long)params.cols];

    _hud.label.numberOfLines = 2;
    _hud.label.text = [NSString stringWithFormat:@"%@\n%@", title, geometry];
  }

  [_hud hideAnimated:YES afterDelay:1.f];
  
  [_touchOverlay.controlPanel updateLayoutBar];
}

- (void)closeCurrentSpace
{
  [self.currentTerm terminate];
  [self removeCurrentSpace];
}

- (void)removeCurrentSpace {
  
  NSInteger idx = [_ctrls indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    return;
  }
  return;
  // TODO:

//  NSInteger numViewports = [_viewports count];
//
//  __weak typeof(self) weakSelf = self;
//  if (idx == 0 && numViewports == 1) {
//    // Only one viewport. Create a new one to replace this
//    [_viewports removeObjectAtIndex:0];
//    [self _createShellWithUserActivity: nil sessionStateKey:nil animated:NO completion:nil];
//  } else if (idx >= [_viewports count] - 1) {
//    // Last viewport, go to the previous.
//    [_viewports removeLastObject];
//    [_viewportsController setViewControllers:@[ _viewports[idx - 1] ]
//           direction:UIPageViewControllerNavigationDirectionReverse
//            animated:YES
//          completion:^(BOOL didComplete) {
//            // Remove viewport from the list after animation
//            if (didComplete) {
//              [weakSelf _displayHUD];
//              [weakSelf _attachInputToCurrentTerm];
//            }
//          }];
//  } else {
//    [_viewports removeObjectAtIndex:idx];
//    [_viewportsController setViewControllers:@[ _viewports[idx] ]
//           direction:UIPageViewControllerNavigationDirectionForward
//            animated:YES
//          completion:^(BOOL didComplete) {
//            // Remove viewport from the list after animation
//            if (didComplete) {
//              [weakSelf _displayHUD];
//              [weakSelf _attachInputToCurrentTerm];
//            }
//          }];
//  }
}

- (void)_createShellWithUserActivity:(NSUserActivity *) userActivity
                     sessionStateKey:(NSString *)sessionStateKey
                            animated:(BOOL)animated
                          completion:(void (^)(BOOL finished))completion
{
  if (!sessionStateKey) {
    sessionStateKey = NSProcessInfo.processInfo.globallyUniqueString;
  }
  TermController *term = [[TermController alloc] init];
  term.sessionStateKey = sessionStateKey;
  term.delegate = self;
  term.userActivity = userActivity;
  term.bgColor = self.view.backgroundColor ?: [UIColor blackColor];
  
  NSInteger numViewports = [_ctrls count];
  

  if (numViewports == 0) {
    [_ctrls addObject:term];
    _splitViewController.root.key = sessionStateKey;
  } else {
    LayoutNode *node = [[LayoutNode alloc] initWithKey:sessionStateKey];
    NSInteger idx = [_ctrls indexOfObject:self.currentTerm];
    if (idx == numViewports - 1) {
      // If it is the last one, insert there.
      [_ctrls addObject:term];
      [_splitViewController.root insertAt:[NSIndexPath indexPathForRow:idx inSection:0] node:node flow:LayoutFlowColumn];
    } else {
      // Insert next to the current terminal.
      [_ctrls insertObject:term atIndex:idx + 1];
      [_splitViewController.root insertAt:[NSIndexPath indexPathForRow:idx + 1 inSection:0] node:node flow:LayoutFlowColumn];
    }
  }
  _ctrlsMap[sessionStateKey] = term;
  [_splitViewController.collectionViewLayout invalidateLayout];
  [_splitViewController.collectionView reloadData];
}

#pragma mark TermControlDelegate

- (void)terminalHangup:(TermController *)control
{
  // Close the Space if the terminal finishing is the current one.
  if (self.currentTerm == control) {
    [self closeCurrentSpace];
  }
}

- (void)terminalDidResize:(TermController*)control
{
  if (control == self.currentTerm) {
    [self _displayHUD];
  }
}

#pragma mark External Keyboard

- (NSArray<UIKeyCommand *> *)keyCommands
{
  if (_musicHUD) {
    return [[MusicManager shared] keyCommands];
  }

  NSMutableDictionary *kbMapping = [NSMutableDictionary dictionaryWithDictionary:[BKDefaults keyboardMapping]];
  if([kbMapping objectForKey:@"⌘ Cmd"] && ![[kbMapping objectForKey:@"⌘ Cmd"]isEqualToString:@"None"]){
    return _kbdCommandsWithoutDiscoverability;
  }
  return _kbdCommands;
}

- (void)keyboardFuncTriggerChanged:(NSNotification *)notification
{
  NSDictionary *action = [notification userInfo];
  if ([action[@"func"] isEqual:BKKeyboardFuncShortcutTriggers]) {
    [self setKbdCommands];
  }
}

- (void)setKbdCommands
{
  UIKeyModifierFlags modifierFlags = [BKUserConfigurationManager shortCutModifierFlags];
  UIKeyModifierFlags prevNextShellModifierFlags = [BKUserConfigurationManager shortCutModifierFlagsForNextPrevShell];
  
  _kbdCommands = [[NSMutableArray alloc] initWithObjects:
                  [UIKeyCommand keyCommandWithInput: @"t" modifierFlags:modifierFlags
                                             action: @selector(newShell:)
                               discoverabilityTitle: @"New shell"],
                  [UIKeyCommand keyCommandWithInput: @"w" modifierFlags: modifierFlags
                                             action: @selector(closeShell:)
                               discoverabilityTitle: @"Close shell"],
                  [UIKeyCommand keyCommandWithInput: @"]" modifierFlags: prevNextShellModifierFlags
                                             action: @selector(nextShell:)
                               discoverabilityTitle: @"Next shell"],
                  [UIKeyCommand keyCommandWithInput: @"[" modifierFlags: prevNextShellModifierFlags
                                             action: @selector(prevShell:)
                               discoverabilityTitle: @"Previous shell"],
                  // Alternative key commands for keyboard layouts having problems to access
                  // some of the default ones (e.g. the German keyboard layout)
                  [UIKeyCommand keyCommandWithInput: UIKeyInputRightArrow modifierFlags: prevNextShellModifierFlags
                                             action: @selector(nextShell:)],
                  [UIKeyCommand keyCommandWithInput: UIKeyInputLeftArrow modifierFlags: prevNextShellModifierFlags
                                             action: @selector(prevShell:)],
                  
                  
                  [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: modifierFlags
                                             action: @selector(otherScreen:)
                               discoverabilityTitle: @"Other Screen"],
                  [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: prevNextShellModifierFlags
                                             action: @selector(moveToOtherScreen:)
                               discoverabilityTitle: @"Move shell to other Screen"],
                  [UIKeyCommand keyCommandWithInput: @"," modifierFlags: modifierFlags
                                             action: @selector(showConfig:)
                               discoverabilityTitle: @"Show config"],
                  
                  [UIKeyCommand keyCommandWithInput: @"m" modifierFlags: modifierFlags
                                             action: @selector(_toggleMusicHUD)
                               discoverabilityTitle: @"Music Controls"],
                  
                  [UIKeyCommand keyCommandWithInput:@"+"
                                      modifierFlags:modifierFlags
                                             action:@selector(_increaseFontSize:)
                               discoverabilityTitle:@"Zoom In"],
                  [UIKeyCommand keyCommandWithInput:@"-"
                                      modifierFlags:modifierFlags
                                             action:@selector(_decreaseFontSize:)
                               discoverabilityTitle:@"Zoom Out"],
                  [UIKeyCommand keyCommandWithInput:@"="
                                      modifierFlags:modifierFlags
                                             action:@selector(_resetFontSize:)
                               discoverabilityTitle:@"Reset Zoom"],
                  nil];
  
  UIKeyCommand * cmd = [UIKeyCommand keyCommandWithInput: @"0-9"
                                         modifierFlags: modifierFlags
                                                action: @selector(switchToShellN:)
                                  discoverabilityTitle: @"Switch to shell 0-9" ];
  [_kbdCommands addObject:cmd];
  
  for (NSInteger i = 1; i < 11; i++) {
    NSInteger keyN = i % 10;
    NSString *input = [NSString stringWithFormat:@"%li", (long)keyN];
    UIKeyCommand * cmd = [UIKeyCommand keyCommandWithInput: input
                                             modifierFlags: modifierFlags
                                                    action: @selector(switchToShellN:)];
    
    [_kbdCommands addObject:cmd];
  }
  
  for (UIKeyCommand *command in _kbdCommands) {
    UIKeyCommand *commandWithoutDiscoverability = [command copy];
    commandWithoutDiscoverability.discoverabilityTitle = nil;
    [_kbdCommandsWithoutDiscoverability addObject:commandWithoutDiscoverability];
  }
  
}

- (void)_increaseFontSize:(UIKeyCommand *)cmd
{
  [self.currentDevice.view increaseFontSize];
}

- (void)_decreaseFontSize:(UIKeyCommand *)cmd
{
  [self.currentDevice.view decreaseFontSize];
}

- (void)_resetFontSize:(UIKeyCommand *)cmd
{
  [self.currentDevice.view resetFontSize];
}

- (void)otherScreen:(UIKeyCommand *)cmd
{
  if ([UIScreen screens].count == 1) {
    if (_termInput.isFirstResponder) {
      [_termInput resignFirstResponder];
    } else {
      [self _focusOnShell];
    }
    return;
  }
  [[ScreenController shared] switchToOtherScreen];
}

- (void)newShell:(UIKeyCommand *)cmd
{
  [self _createShellWithUserActivity: nil sessionStateKey:nil animated:YES completion:nil];
}

- (void)closeShell:(UIKeyCommand *)cmd
{
  [self closeCurrentSpace];
}

- (void)moveToOtherScreen:(UIKeyCommand *)cmd
{
  [[ScreenController shared] moveCurrentShellToOtherScreen];
}

- (void)showConfig:(UIKeyCommand *)cmd 
{
  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
  UINavigationController *vc = [sb instantiateViewControllerWithIdentifier:@"NavSettingsController"];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    UIViewController *rootVC = ScreenController.shared.mainScreenRootViewController;
    [rootVC presentViewController:vc animated:YES completion:NULL];
  }];
}

- (void)switchShellIdx:(NSInteger)idx animated:(BOOL) animated
{
  if (idx < 0 || idx >= _ctrls.count) {
    [self _displayHUD];
    return;
  }

  [_splitViewController.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:animated];
  _currentCtrlIdx = idx;
}

- (void)nextShell:(UIKeyCommand *)cmd
{
  [self switchShellIdx: _currentCtrlIdx + 1 animated: YES];
}

- (void)prevShell:(UIKeyCommand *)cmd
{
  [self switchShellIdx: _currentCtrlIdx - 1 animated: YES];
}

- (void)switchToShellN:(UIKeyCommand *)cmd
{
  NSInteger targetIdx = [cmd.input integerValue];
  if (targetIdx <= 0) {
    targetIdx = 10;
  }
  
  targetIdx -= 1;
  [self switchToTargetIndex:targetIdx];
}

- (void)switchToTargetIndex:(NSInteger)targetIdx
{
  [self switchShellIdx: targetIdx
              animated: YES];
}

# pragma moving spaces

- (void)moveAllShellsFromSpaceController:(SpaceController *)spaceController
{
  for (TermController *ctrl in spaceController->_ctrls) {
    ctrl.delegate = self;
    [_ctrls addObject:ctrl];
  }

  [self _displayHUD];
}

- (void)moveCurrentShellFromSpaceController:(SpaceController *)spaceController
{
  TermController *term = spaceController.currentTerm;
  term.delegate = self;
  [_ctrls addObject:term];
  [spaceController removeCurrentSpace];
  [self _displayHUD];
}

- (void)viewScreenWillBecomeActive
{
  [self _displayHUD];
  [_termInput becomeFirstResponder];
}

- (void)viewScreenDidBecomeInactive
{
  [_termInput resignFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  // Fix for github issue #299
  // Even app is not in active state it still recieves actions like CMD+T and etc.
  // So we filter them here.
  
  UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
  
  if (appState != UIApplicationStateActive) {
    return NO;
  }
  
  return [super canPerformAction:action withSender:sender];
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
  // somehow we don't have current term... so we just create new one
  NSInteger idx = [_ctrls indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    [self _createShellWithUserActivity:activity sessionStateKey:nil animated:YES completion:nil];
    return;
  }


  // 1. Find terminal with excact command that is running right now
  NSInteger targetIdx = [_ctrls indexOfObjectPassingTest:^BOOL(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    return [activity.title isEqualToString:term.activityKey] && [term isRunningCmd];
  }];
  
  if (targetIdx != NSNotFound) {
    // current terminal is running this command, so just stay here.
    if (idx == targetIdx) {
      [self _attachInputToCurrentTerm];
      return;
    }
    
    [self switchShellIdx: targetIdx animated: NO];
    return;
  }

  // 2. Check if current term can run command.
  if ([self.currentTerm canRestoreUserActivityState:activity]) {
    [self _attachInputToCurrentTerm];
    [self.currentTerm.termDevice focus];
    [self.currentTerm restoreUserActivityState:activity];
    return;
  }
  
  // 3. Find terminal that can run this command.
  targetIdx = [_ctrls indexOfObjectPassingTest:^BOOL(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    return [term canRestoreUserActivityState:activity];
  }];
  
  // No running terminals can run this command, so we creating new one.
  if (targetIdx == NSNotFound) {
    [self _createShellWithUserActivity:activity sessionStateKey:nil animated:YES completion:nil];
    return;
  }
  
  TermController *term = _ctrls[targetIdx];
  [term.termDevice attachInput:_termInput];
  [term.termDevice focus];
  [term restoreUserActivityState:activity];
  [self switchShellIdx: targetIdx animated: NO];
}

- (void)suspendWith:(StateManager *) stateManager
{
  for (TermController * term in _ctrls) {
    [term suspend];
    [stateManager snapshotState:term];
  }
}

- (void)resumeWith:(StateManager *)stateManager
{
  for (TermController * term in _ctrls) {
    [stateManager restoreState:term];
    [term resume];
  };
}

- (void)musicCommand:(UIKeyCommand *)cmd
{
  [[MusicManager shared] handleCommand:cmd];
  [self _toggleMusicHUD];
}

- (void)touchOverlay:(TouchOverlay *)overlay onOneFingerTap:(UITapGestureRecognizer *)recognizer
{
  [_termInput reset];
  TermController * term = self.currentTerm;
  CGPoint point = [recognizer locationInView:term.view];
  [term.termDevice focus];
  [term.termDevice.view reportTouchInPoint: point];
}

- (void)touchOverlay:(TouchOverlay *)overlay onTwoFingerTap:(UITapGestureRecognizer *)recognizer
{
  [self _createShellWithUserActivity: nil sessionStateKey: nil animated:YES completion:nil];
}

- (void)touchOverlay:(TouchOverlay *)overlay onPinch:(UIPinchGestureRecognizer *)recognizer
{
  [self.currentTerm scaleWithPich:recognizer];
}

-(void)controlPanelOnPaste
{
  [self _attachInputToCurrentTerm];
  [_termInput yank:self];
}

- (void)controlPanelOnClose
{
  [self closeCurrentSpace];
}

- (void)copy:(id)sender
{
  // Accessibility speak try to copy selection. (notices on iphone)
  if (sender == nil) {
    return;
  }

  [_termInput copy: sender];
}

- (void)paste:(id)sender
{
  [self controlPanelOnPaste];
}
  
- (void)pasteSelection:(id)sender
{
  [self _attachInputToCurrentTerm];
  [_termInput pasteSelection:sender];
}

- (void)copyLink:(id)sender
{
  [self _attachInputToCurrentTerm];
  [_termInput copyLink:sender];
}

- (void)openLink:(id)sender
{
  [self _attachInputToCurrentTerm];
  [_termInput openLink:sender];
}

#pragma mark - UIDropInteractionDelegate

- (BOOL)dropInteraction:(UIDropInteraction *)interaction canHandleSession:(id<UIDropSession>)session
API_AVAILABLE(ios(11.0)){
  BOOL res = [session canLoadObjectsOfClass:[NSString class]];
  if (res) {
    [_termInput reset];
    _termInput.frame = self.view.bounds;
    _termInput.alpha = 0.02;
    _termInput.hidden = NO;
    _termInput.backgroundColor = [UIColor clearColor];
    [self.view bringSubviewToFront:_termInput];
    [self _focusOnShell];
  }
   return res;
}

- (UIDropProposal *)dropInteraction:(UIDropInteraction *)interaction sessionDidUpdate:(id<UIDropSession>)session
API_AVAILABLE(ios(11.0)){
  return [[UIDropProposal alloc] initWithDropOperation:UIDropOperationCopy];
}

- (void)dropInteraction:(UIDropInteraction *)interaction performDrop:(id<UIDropSession>)session
API_AVAILABLE(ios(11.0)){
  [session loadObjectsOfClass:[NSString class] completion:^(NSArray<__kindof id<NSItemProviderReading>> * _Nonnull objects) {
    NSString * str = [objects firstObject];
    if (str) {
      [self.currentDevice write:str];
      [self.currentDevice.view cleanSelection];
    }
  }];
}

- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidEnd:(id<UIDropSession>)session
API_AVAILABLE(ios(11.0)){
  _termInput.frame = CGRectZero;
  _termInput.hidden = YES;
  [_termInput reset];
}

- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidExit:(id<UIDropSession>)session
API_AVAILABLE(ios(11.0)){
  _termInput.frame = CGRectZero;
  _termInput.hidden = YES;
  [_termInput reset];
}

- (void)_onGeoLock {
  NSUInteger count = _ctrls.count;
  for (int i = 0; i < count; i++) {
    [self removeCurrentSpace];
  }
}

- (void)configureWithSplitViewCell:(LayoutCell * _Nonnull)splitViewCell for:(NSString * _Nonnull)key {
  UIViewController *ctrl = _ctrlsMap[key];
  if (!ctrl) {
    TermController *term = [[TermController alloc] init];
    term.sessionStateKey = key;
    term.delegate = self;
    term.userActivity = nil;
    term.bgColor = self.view.backgroundColor ?: [UIColor blackColor];
    _ctrlsMap[key] = term;
    ctrl = term;
    
  }
  
  [splitViewCell setWithController:ctrl parent:_splitViewController];
}

@end
