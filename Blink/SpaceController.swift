//////////////////////////////////////////////////////////////////////////////////
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


import Foundation
import MBProgressHUD

enum SpaceSection {
  case main
}

class SpaceController: UICollectionViewController {
  
  struct UIState: UserActivityCodable {
    var keys: [UUID] = []
    var currentKey: UUID? = nil
    var bgColor:CodableColor? = nil
    
    static var activityType: String { "space.ctrl.ui.state" }
  }

  private lazy var _touchOverlay = TouchOverlay(frame: .zero)
  
  private var _termsSnapshot = NSDiffableDataSourceSnapshot<SpaceSection, UUID>()
  private var _currentKey: UUID? = nil
  
  private var _hud: MBProgressHUD? = nil
  
  private var _kbdCommands:[UIKeyCommand] = []
  private var _kbdCommandsWithoutDiscoverability: [UIKeyCommand] = []
  private var _dataSource: UICollectionViewDiffableDataSource<SpaceSection, UUID>!
  
  init() {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumLineSpacing = 0
    layout.minimumInteritemSpacing = 0
    layout.sectionInset = .zero
    layout.sectionInsetReference = .fromContentInset
    
    _termsSnapshot.appendSections([.main])
    
    super.init(collectionViewLayout: layout)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    debugPrint("willDisplay", indexPath)
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    debugPrint("didEndDisplaying", indexPath)
    if let cell = collectionView.visibleCells.first as? TermCell,
      let term = cell.term {
      if (_currentKey != term.meta.key) {
        _currentKey = term.meta.key
        _attachInputToCurrentTerm()
      }
//      term.termDevice.attachInput(SmarterTermInput.shared)
//      term.termDevice.focus()
      
    }
  }
  
  
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    guard let window = view.window
    else {
      return
    }
    
    if window.screen === UIScreen.main {
      var insets = UIEdgeInsets.zero
      insets.bottom = LayoutManager.mainWindowKBBottomInset()
      // TODO: Bottom insets
      _touchOverlay.frame = view.bounds.inset(by: insets)
    } else {
      _touchOverlay.frame = view.bounds
    }
    
    _commandsHUD.setNeedsLayout()
  }
  
  @objc func _relayout() {
    guard
      let window = view.window,
      window.screen === UIScreen.main
    else {
      return
    }
    
    view.setNeedsLayout()
  }
  
  public override func viewDidLoad() {
    debugPrint("viewDidLoad")
    super.viewDidLoad()
  
    collectionView.allowsMultipleSelection = false
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false

    collectionView.minimumZoomScale = 0.1
    collectionView.maximumZoomScale = 5
    collectionView.keyboardDismissMode = .interactive
    collectionView.isDirectionalLockEnabled = true
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.isPagingEnabled = true
    collectionView.alwaysBounceHorizontal = true
//    collectionView.dropDelegate = self
    
    
    collectionView.register(TermCell.self, forCellWithReuseIdentifier: TermCell.identifier)
    let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    layout?.itemSize = view.bounds.size
    
    _dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] (collectionView, indexPath, key) -> UICollectionViewCell? in
      debugPrint("cellForIndexPathh", indexPath, key)
      guard
        let self = self,
        let termCell = collectionView.dequeueReusableCell(withReuseIdentifier: TermCell.identifier, for: indexPath) as? TermCell
      else {
        return nil
      }
      
      
      termCell.backgroundColor = self.view.backgroundColor
      let term: TermController = SessionRegistry.shared[key]
      term.delegate = self
      self.addChild(term)
      termCell.term = term
      term.didMove(toParent: self)
      
      return termCell;
    }
    _dataSource.apply(_termsSnapshot, animatingDifferences: false)
    
//    _touchOverlay.frame = view.bounds
//    view.addSubview(_touchOverlay)
    _touchOverlay.touchDelegate = self
    
    _commandsHUD.delegate = self
    _registerForNotifications()
    _setupKBCommands()
    
    _commandsHUD.delegate = self
    
    if _termsSnapshot.numberOfItems(inSection: .main) == 0 {
      _createShell(animated:false)
      return
    }

    if let idx = self._termsSnapshot.indexOfItem(self._currentKey ?? UUID()) {
      collectionView.contentOffset = CGPoint(x: CGFloat(idx) * self.view.bounds.width, y: 0)
    }
//    _updateCollectionView(animated: false, initial: true)
  }
  
  func _updateCollectionView(animated: Bool, initial: Bool = false) {
    _dataSource.apply(_termsSnapshot, animatingDifferences: animated) {
      self._termsSnapshot = self._dataSource.snapshot()
      if let idx = self._termsSnapshot.indexOfItem(self._currentKey ?? UUID()) {
        if initial {
          self.collectionView.contentOffset = CGPoint(x: CGFloat(idx) * self.view.bounds.width, y: 0)
        } else {
          self.collectionView.scrollToItem(at: IndexPath(row: idx, section: 0), at: .left, animated: animated)
        }
      }
    }
  }
  


  
  public override func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
    collectionView.isScrollEnabled = false
    currentTerm()?.termDevice.view?.dropTouches()
  }
  
  public override func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
    collectionView.isScrollEnabled = true
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    currentTerm()?.termDevice.view?.dropTouches()
  }
  
  let _commandsHUD = CommandsHUGView(frame: .zero)
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    _didBecomeKeyWindow()
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    debugPrint("viewWillTransition", coordinator.isAnimated)
        
    super.viewWillTransition(to: size, with: coordinator)
    
    
    if let scrollView = collectionView, let layout = self.collectionViewLayout as? UICollectionViewFlowLayout {
      let page = Int(scrollView.contentOffset.x / (view.bounds.width))
      let newOffset = CGPoint(x: CGFloat(page) * (size.width), y: 0)
      let newContentSize = CGSize(width: (size.width) * CGFloat(self._termsSnapshot.numberOfItems(inSection: .main)), height: size.height)
      let newFrame = CGRect(origin: .zero, size: size)
      let ctx1 = UICollectionViewFlowLayoutInvalidationContext()
      ctx1.invalidateFlowLayoutAttributes = true

      coordinator.animateAlongsideTransition(in: nil, animation: { (t) in
        scrollView.frame = newFrame
        scrollView.contentSize = newContentSize
        let offset = CGPoint(x: newOffset.x, y: newOffset.y)
        scrollView.contentOffset = offset
//        let layout2 = UICollectionViewFlowLayout()
//        layout2.scrollDirection = .horizontal
//        layout2.minimumLineSpacing = 10
//        layout2.minimumInteritemSpacing = 10
//        layout2.sectionInset = .zero
        layout.itemSize = size
//        self.collectionView.performBatchUpdates({
        self.collectionView.setCollectionViewLayout(layout, animated: coordinator.isAnimated)
//        }, completion: nil)
//        layout.invalidateLayout(with: ctx1)
      }) { (ctx) in
        
//        layout.itemSize = size
//        if !coordinator.isAnimated {
//          scrollView.setContentOffset(newOffset, animated: true)
//        }
      }
    }
    
//    // Voodoo thing to state on same scroll offset
//    if let cell = collectionView.visibleCells.first,
//      let scrollView = cell.superview as? UIScrollView {
//      let page = Int(scrollView.contentOffset.x / (view.bounds.width + 10))
//      let newOffset = CGPoint(x: CGFloat(page) * (size.width + 10), y: 0)
//      let newContentSize = CGSize(width: (size.width + 10) * CGFloat(self._termsSnapshot.numberOfItems(inSection: .main)), height: size.height)
//
//      coordinator.animateAlongsideTransition(in: view, animation: { (t) in
//        scrollView.frame = CGRect(origin:.zero, size: size)
//        scrollView.contentSize = newContentSize
//        let offset = CGPoint(x: newOffset.x + (coordinator.isAnimated ? 0 : 0.5), y: newOffset.y)
//        scrollView.contentOffset = offset
//      }) { (ctx) in
//        if !coordinator.isAnimated {
//          scrollView.setContentOffset(newOffset, animated: true)
//        }
//      }
//    }
    
    
    if view.window?.isKeyWindow == true {
      DispatchQueue.main.async {
        SmarterTermInput.shared.reloadInputViews()
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func _registerForNotifications() {
    let nc = NotificationCenter.default
    
    nc.addObserver(self,
                   selector: #selector(_focusOnShell),
                   name: NSNotification.Name.BKUserAuthenticated,
                   object: nil)
    
    nc.addObserver(self,
                   selector: #selector(_didBecomeKeyWindow),
                   name: UIWindow.didBecomeKeyNotification,
                   object: nil)
    
    nc.addObserver(self, selector: #selector(_relayout),
                   name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate),
                   object: nil)
  }
  
  @objc func _didBecomeKeyWindow() {
    guard let window = view.window else {
      currentDevice?.blur()
      return
    }
    
    if window.isKeyWindow {
      if SmarterTermInput.shared.superview !== self.view
        && window.screen === UIScreen.main {
          view.addSubview(SmarterTermInput.shared)
        }
      _focusOnShell()
      DispatchQueue.main.async {
        if let win = self.view.window?.windowScene?.windows.last, win !== self.view.window,
          self._commandsHUD.superview == nil {
          self._commandsHUD.attachToWindow(inputWindow: win)
        }
      }
    } else {
      currentDevice?.blur()
    }
  }
  
  
  @objc func _keyboardFuncTriggerChanged(_ notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      let action = userInfo["func"] as? String,
      action == BKKeyboardFuncCursorTriggers
    else {
      return
    }
    
    _setupKBCommands()
  }
  
  func _createShell(animated: Bool)
  {
    let term: TermController = SessionRegistry.shared[UUID()]
    term.delegate = self
    
    if let currentKey = _currentKey {
      _termsSnapshot.insertItems([term.meta.key], afterItem: currentKey)
    } else {
      _termsSnapshot.appendItems([term.meta.key])
    }
    
    _currentKey = term.meta.key
    _attachInputToCurrentTerm()
    _updateCollectionView(animated: animated)
  }
  
  func _closeCurrentSpace() {
    currentTerm()?.terminate()
    _removeCurrentSpace()
  }
  
  
  private func _removeCurrentSpace() {
    guard
      let currentKey = _currentKey,
      let _ = _termsSnapshot.indexOfItem(currentKey)
    else {
      return
    }
    currentTerm()?.delegate = nil
    SessionRegistry.shared.remove(forKey: currentKey)
    _termsSnapshot.deleteItems([currentKey])
    
    if _termsSnapshot.numberOfItems(inSection: .main) == 0 {
      _currentKey = nil
      _createShell(animated: true)
      return
    }

    _updateCollectionView(animated: true)
  }
  
  @objc func _focusOnShell() {
    if let idx = collectionView.indexPathsForVisibleItems.first,
      let key = _dataSource.itemIdentifier(for: idx) {
      _currentKey = key
    }
    _attachInputToCurrentTerm()
    if !SmarterTermInput.shared.isFirstResponder {
      _ = SmarterTermInput.shared.becomeFirstResponder()
    }
  }
  
  func _attachInputToCurrentTerm() {
    currentDevice?.attachInput(SmarterTermInput.shared)
    currentDevice?.focus()
  }
  
  var currentDevice: TermDevice? {
    currentTerm()?.termDevice
  }
  
  @objc public func moveAllShellsFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  @objc public func moveCurrentShellFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  func _displayHUD() {
    _hud?.hide(animated: false)
    
    guard let term = currentTerm() else {
      return
    }
    
    let params = term.sessionParams
    
    if let bgColor = term.view.backgroundColor, bgColor != .clear {
      view.window?.backgroundColor = bgColor
    }
    
    let hud = MBProgressHUD.showAdded(to: _touchOverlay, animated: _hud == nil)
    
    hud.mode = .customView
    hud.bezelView.color = .darkGray
    hud.contentColor = .white
    hud.isUserInteractionEnabled = false
    hud.alpha = 0.6
    
    let pages = UIPageControl()
    pages.currentPageIndicatorTintColor = .cyan
    pages.numberOfPages = _termsSnapshot.numberOfItems(inSection: .main)
    let pageNum = _termsSnapshot.indexOfItem(term.meta.key)
    pages.currentPage = pageNum ?? NSNotFound
    
    hud.customView = pages
    
    let title = term.title?.isEmpty == true ? nil : term.title
    
    var sceneTitle = "[\(pageNum == nil ? 1 : pageNum! + 1) of \(_termsSnapshot.numberOfItems(inSection: .main))] \(title ?? "blink")"
    
    if params.rows == 0 && params.cols == 0 {
      hud.label.numberOfLines = 1
      hud.label.text = title ?? "blink"
    } else {
      let geometry = "\(params.cols)×\(params.rows)"
      hud.label.numberOfLines = 2
      hud.label.text = "\(title ?? "blink")\n\(geometry)"
      
      sceneTitle += " | " + geometry
    }
    
    _hud = hud
    hud.hide(animated: true, afterDelay: 1)
    
    view.window?.windowScene?.title = sceneTitle
  }
  
}

extension SpaceController: UIStateRestorable {
  func restore(withState state: UIState) {
    var snapshot = NSDiffableDataSourceSnapshot<SpaceSection, UUID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(state.keys)
    _termsSnapshot = snapshot
    _currentKey = state.currentKey
    if let bgColor = UIColor(codableColor: state.bgColor) {
      view.backgroundColor = bgColor
    }
  }
  
  func dumpUIState() -> UIState {
    UIState(keys: _termsSnapshot.itemIdentifiers(inSection: .main),
            currentKey: _currentKey,
            bgColor: CodableColor(uiColor: view.backgroundColor)
    )
  }
  
  @objc static func onDidDiscardSceneSessions(_ sessions: Set<UISceneSession>) {
    let registry = SessionRegistry.shared
    for session in sessions {
      guard
        let uiState = UIState(userActivity: session.stateRestorationActivity)
      else {
        continue
      }
      
      uiState.keys.forEach { registry.remove(forKey: $0) }
    }
  }
}

//extension SpaceController: UIPageViewControllerDelegate {
//  public func pageViewController(
//    _ pageViewController: UIPageViewController,
//    didFinishAnimating finished: Bool,
//    previousViewControllers: [UIViewController],
//    transitionCompleted completed: Bool) {
//    guard completed else {
//      return
//    }
//
//    guard let termController = pageViewController.viewControllers?.first as? TermController
//    else {
//      return
//    }
//    _currentKey = termController.meta.key
//    _displayHUD()
//    _attachInputToCurrentTerm()
//  }
//}


extension SpaceController: TouchOverlayDelegate {
  public func touchOverlay(_ overlay: TouchOverlay!, onOneFingerTap recognizer: UITapGestureRecognizer!) {
    guard let term = currentTerm() else {
      return
    }
    SmarterTermInput.shared.reset()
    let point = recognizer.location(in: term.view)
    _focusOnShell()
    term.termDevice.view.reportTouch(in: point)
  }
  
  public func touchOverlay(_ overlay: TouchOverlay!, onTwoFingerTap recognizer: UITapGestureRecognizer!) {
    _createShell(animated: true)
  }
  
  public func touchOverlay(_ overlay: TouchOverlay!, onPinch recognizer: UIPinchGestureRecognizer!) {
    currentTerm()?.scaleWithPich(recognizer)
  }
}

extension SpaceController: TermControlDelegate {
  func terminalHangup(control: TermController) {
    if currentTerm() == control {
      _closeCurrentSpace()
    }
  }
  
  func terminalDidResize(control: TermController) {
    if currentTerm() == control {
      _displayHUD()
    }
  }
}

// MARK: General tunning

extension SpaceController {
  public override var canBecomeFirstResponder: Bool { true }
  public override var prefersStatusBarHidden: Bool { true }
  public override var prefersHomeIndicatorAutoHidden: Bool { true }
}


// MARK: Commands

extension SpaceController {
  public override var keyCommands: [UIKeyCommand]? {
    return _kbdCommands
  }
  
  // simple helper
  private func _cmd(_ title: String, _ action: Selector, _ input: String, _ flags: UIKeyModifierFlags) -> UIKeyCommand {
    return UIKeyCommand(
      __title: title,
      image: nil,
      action: action,
      input: input,
      modifierFlags: flags,
      propertyList: nil
    )
  }
  
  private func _setupKBCommands() {
    let modifierFlags = BKUserConfigurationManager.shortCutModifierFlags()
    let prevNextShellModifierFlags = BKUserConfigurationManager.shortCutModifierFlagsForNextPrevShell()
    
    let right = UIKeyCommand.inputRightArrow
    let left = UIKeyCommand.inputLeftArrow
    
    _kbdCommands = [
      _cmd("New Window",     #selector(_newWindowAction),   "t", prevNextShellModifierFlags),
      _cmd("Close Window",   #selector(_closeWindowAction), "w", prevNextShellModifierFlags),
    
      _cmd("New Shell",      #selector(newShellAction),   "t", modifierFlags),
      _cmd("Close Shell",    #selector(closeShellAction), "w", modifierFlags),
      
      _cmd("Next Shell",     #selector(_nextShellAction), "]", prevNextShellModifierFlags),
      _cmd("Previous Shell", #selector(_prevShellAction), "[", prevNextShellModifierFlags),
    
      // Alternative key commands for keyboard layouts having problems to access
      // some of the default ones (e.g. the German keyboard layout)
      _cmd("Next Shell",     #selector(_nextShellAction),  right, prevNextShellModifierFlags),
      _cmd("Previous Shell", #selector(_prevShellAction),  left,  prevNextShellModifierFlags),
      
      // Font size
      _cmd("Zoom In",    #selector(_increaseFontSizeAction), "+",  modifierFlags),
      _cmd("Zoom Out",   #selector(_decreaseFontSizeAction), "-",  modifierFlags),
      _cmd("Zoom Reset", #selector(_resetFontSizeAction),    "=",  modifierFlags),
      
      // Screens
      _cmd("Focus Other Screen",         #selector(_focusOtherScreenAction),  "o", modifierFlags),
      _cmd("Move shell to other Screen", #selector(_moveToOtherScreenAction), "o", prevNextShellModifierFlags),
      
      // Misc
      _cmd("Show Config",    #selector(_showConfigAction), ",", modifierFlags),
    ]
  }
  
  @objc func newShellAction() {
    _createShell(animated: true)
  }
  
  @objc func closeShellAction() {
    _closeCurrentSpace()
  }
  
  private func _moveToShell(idx: Int) {
    let viewPorts = _termsSnapshot.itemIdentifiers(inSection: .main)
    guard
      idx >= viewPorts.startIndex,
      idx < viewPorts.endIndex
    else {
      return
    }
    
    let id = viewPorts[idx]
    
    if let path = _dataSource.indexPath(for: id) {
      collectionView.scrollToItem(at: path, at: .left, animated: true)
    }
  }
  
  private func _advanceShell(by: Int) {
    guard
      let currentKey = _currentKey,
      let idx = _termsSnapshot.indexOfItem(currentKey)?.advanced(by: by)
    else {
      return
    }
        
    _moveToShell(idx: idx)
  }
  
  @objc private func _nextShellAction() {
    _advanceShell(by: 1)
  }
  
  @objc private func _prevShellAction() {
    _advanceShell(by: -1)
  }
  
  
  @objc func _focusOtherScreenAction() {
    let app = UIApplication.shared
    let sessions = Array(app.openSessions)
      .sorted(by: {(a, b) in
      a.persistentIdentifier > b.persistentIdentifier
    })
//    view.window?.windowScene?.session.persistentIdentifier
    guard
      sessions.count > 1,
      let session = view.window?.windowScene?.session,
      let idx = sessions.firstIndex(of: session)?.advanced(by: 1)
    else  {
      return
    }
    
    let nextSession: UISceneSession
    if idx < sessions.endIndex {
      nextSession = sessions[idx]
    } else {
     nextSession = sessions[0]
    }
    
    if
      let scene = nextSession.scene as? UIWindowScene,
      scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive,
      let delegate = scene.delegate as? SceneDelegate,
      let window = delegate.window,
      let spaceCtrl = window.rootViewController as? SpaceController {
        if nextSession.role == .windowExternalDisplay || window.isKeyWindow {
          spaceCtrl._focusOnShell()
        } else {
          window.makeKeyAndVisible()
        }
    } else {
      app.requestSceneSessionActivation(nextSession, userActivity: nil, options: nil, errorHandler: nil)
    }
  }
  
  @objc func _moveToOtherScreenAction() {
    
  }
  
  @objc func _newWindowAction() {
    UIApplication
      .shared
      .requestSceneSessionActivation(nil,
                                     userActivity: nil,
                                     options: nil,
                                     errorHandler: nil)
  }
  
  @objc func _closeWindowAction() {
    guard
      let session = view.window?.windowScene?.session,
      session.role == .windowApplication // Can't close windows on external monitor
    else {
      return
    }
    UIApplication
      .shared
      .requestSceneSessionDestruction(session,
                                      options: nil,
                                      errorHandler: nil)
  }
  
  @objc func _increaseFontSizeAction() {
    currentDevice?.view?.increaseFontSize()
  }
  
  @objc func _decreaseFontSizeAction() {
    currentDevice?.view?.decreaseFontSize()
  }
  
  @objc func _resetFontSizeAction() {
    currentDevice?.view?.resetFontSize()
  }
  
  @objc func _showConfigAction() {
    DispatchQueue.main.async {
      let storyboard = UIStoryboard(name: "Settings", bundle: nil)
      let vc = storyboard.instantiateViewController(identifier: "NavSettingsController")
      self.present(vc, animated: true, completion: nil)
    }
  }
  
}

extension SpaceController: CommandsHUDViewDelegate {
  @objc func currentTerm() -> TermController? {
    if let currentKey = _currentKey {
      return SessionRegistry.shared[currentKey]
    }
    return nil
  }
  
  @objc func spaceController() -> SpaceController? {
    return self
  }
}

extension SpaceController: UICollectionViewDelegateFlowLayout{
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize{
    self.view.bounds.size
  }
  
  
}

extension SpaceController: UICollectionViewDropDelegate {
  func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
    
  }
  
  func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
    return false
  }
  
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
//    collectionView.
    
    return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
//    let cell = collectionView.cellForItem(at: indexPath) as! TermCell
    let previewParameters = UIDragPreviewParameters()
//    previewParameters.visiblePath = UIBezierPath(rect: cell.clippingRectForPhoto)
    return previewParameters
  }
  
  
}
