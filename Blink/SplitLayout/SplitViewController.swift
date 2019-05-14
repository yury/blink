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

import UIKit

class LayoutResizeContext {
  fileprivate let frame: CGRect
  fileprivate var invalidationContext = UICollectionViewLayoutInvalidationContext()
  fileprivate var splitNode: LayoutNode
  
  fileprivate init(frame: CGRect, splitNode: LayoutNode) {
    self.frame = frame
    self.splitNode = splitNode
  }
}

@objc public protocol SplitViewControllerDelegate: class {
  func configure(splitViewCell: LayoutCell, for key: String)
}

@objc public class SplitViewController: UICollectionViewController {
  var _root: LayoutNode
  @objc public var root: LayoutNode { get { return _root }}
  var _longPress2TouchesRecognizer: UILongPressGestureRecognizer?
  var _resizeCtx: LayoutResizeContext? = nil
  @objc public weak var splitViewDelegate: SplitViewControllerDelegate? = nil
  
  @objc public init(splitLayout: CollectionViewSplitLayout) {
    _root = splitLayout.root
    super.init(collectionViewLayout: splitLayout)
  }
  
  required init?(coder aDecoder: NSCoder) {
    _root = LayoutNode(key: genNodeKey())
    super.init(coder: aDecoder)
  }

  @objc func _onTap(recognizer: UITapGestureRecognizer) {
    guard let cv = collectionView else {
      return
    }
    switch recognizer.state {
    case .began:
      let loc1 = recognizer.location(ofTouch: 0, in: cv)
      let loc2 = recognizer.location(ofTouch: 1, in: cv)
      
      guard
        let ip1 = cv.indexPathForItem(at: loc1),
        let ip2 = cv.indexPathForItem(at: loc2),
        let c1 = cv.cellForItem(at: ip1),
        let n1 = _root.node(at: ip1)
        else {
          return
      }
      
      // splitting
      if ip1 == ip2 {
        let dx = abs(loc1.x - loc2.x)
        let dy = abs(loc1.y - loc2.y)
        let flow: LayoutFlow =  dx > dy ? .column : .row
        
        let ratio: CGFloat
        switch flow {
        case .column:
          ratio = (min(loc1.x, loc2.x) + dx * 0.5 - c1.frame.minX) / c1.frame.width
        case .row:
          ratio = (min(loc1.y, loc2.y) + dy * 0.5 - c1.frame.minY) / c1.frame.height
        }
        
        let ctx = LayoutResizeContext(frame: c1.frame, splitNode: n1)
        ctx.invalidationContext = collectionViewLayout.invalidationContext(forBoundsChange: ctx.frame)
        
        _resizeCtx = ctx
        
        n1.split(with: LayoutNode(key: genNodeKey()), flow: flow, at: ratio)
        var indexPath = ip1
        indexPath.row += 1
        cv.insertItems(at: [indexPath])
        
        
        return
      }
      // TODO: grab ctx for different cells
      guard
        let n2 = _root.node(at: ip2),
        let c2 = cv.cellForItem(at: ip2),
        let commonNode = n2.commonParent(n1),
        let split = commonNode.split
        else {
          return
      }
      
    case .changed:
      
      guard
        let ctx = _resizeCtx,
        let split = ctx.splitNode.split
        else {
          return
      }
      
      let loc1 = recognizer.location(ofTouch: 0, in: cv)
      let loc2 = recognizer.location(ofTouch: 1, in: cv)
      
      let dx = abs(loc1.x - loc2.x)
      let dy = abs(loc1.y - loc2.y)
      
      let frame = ctx.frame
      
      let ratio: CGFloat
      switch split.flow {
      case .column:
        ratio = (min(loc1.x, loc2.x) + dx * 0.5 - frame.minX) / frame.width
      case .row:
        ratio = (min(loc1.y, loc2.y) + dy * 0.5 - frame.minY) / frame.height
      }
      
      ctx.splitNode.split?.ratio = ratio
      collectionViewLayout.invalidateLayout()
      
    case .cancelled, .failed, .ended: break
    default: break
    }
  }
  
  override public var collectionViewLayout: CollectionViewSplitLayout {
    get { return super.collectionViewLayout as! CollectionViewSplitLayout }
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    
    let longPress2TouchRecognizer = UILongPressGestureRecognizer(
      target: self,
      action: #selector(SplitViewController._onTap(recognizer:))
    )
    _longPress2TouchesRecognizer = longPress2TouchRecognizer
    longPress2TouchRecognizer.numberOfTouchesRequired = 2
    view.addGestureRecognizer(longPress2TouchRecognizer)
    
    collectionView.register(
      LayoutCell.self,
      forCellWithReuseIdentifier: LayoutElement.cell
    )
    
    collectionView.register(
      LayoutSeparatorView.self,
      forSupplementaryViewOfKind: LayoutElement.separator,
      withReuseIdentifier:LayoutElement.separator
    )
  }
  
  override public func numberOfSections(in collectionView: UICollectionView) -> Int {
    return collectionViewLayout.root.numberOfSections()
  }
  
  override public func collectionView(
    _ collectionView: UICollectionView,
    viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath) -> UICollectionReusableView {
    
    return collectionView.dequeueReusableSupplementaryView(
      ofKind: LayoutElement.separator,
      withReuseIdentifier: LayoutElement.separator,
      for: indexPath
    )
  }
  
  override public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    guard
      let node = _root.node(at: indexPath),
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: LayoutElement.cell,
        for: indexPath
        ) as? LayoutCell
      else {
        return UICollectionViewCell()
    }
   
    self.splitViewDelegate?.configure(splitViewCell: cell, for: node.key)
    
    return cell
  }
  
  override public func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
    ) -> Int {
    
    return _root.numberOfItemsIn(
      section: section
    )
  }
}




//let root = LayoutNode(key: "0")
//let layout = CollectionViewSplitLayout(root: root)
//
//let ctrl = ViewController(splitLayout: layout)
//let nav = UINavigationController(rootViewController: ctrl)
//
//PlaygroundPage.current.liveView = nav
//
