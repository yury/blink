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

// shortcut type
typealias LayoutAttrs = UICollectionViewLayoutAttributes

struct LayoutElement {
  static let cell = "cell"
  static let separator = "separator"
}

@objc public enum LayoutFlow: Int {
  case row = 0
  case column = 1
}

struct LayoutSplit {
  let flow: LayoutFlow
  var ratio: CGFloat
  let nodes: (a: LayoutNode, b: LayoutNode)
}

public class LayoutNode: NSObject {
  @objc public var key: String
  
  weak var parent: LayoutNode? = nil;
  
  private(set) var attrs = __attrs(for: nil)
  
  var split: LayoutSplit? = nil {
    didSet {
      
      attrs = LayoutNode.__attrs(for: split)
    }
  }
  
  @objc public init(key: String) {
    self.key = key
  }
  
  private static func __attrs(
    for split: LayoutSplit?
    ) -> LayoutAttrs {
    
    let result: LayoutAttrs
    let path = IndexPath(row: 0, section: 0)
    
    if split == nil {
      result = LayoutAttrs(forCellWith: path)
    } else {
      result = LayoutAttrs(
        forSupplementaryViewOfKind: LayoutElement.separator,
        with: path)
    }
    
    return result
  }
  
  func split(
    at indexPath: IndexPath
    ) -> LayoutNode? {
    
    var splitPos: Int = 0
    return _split(
      at: indexPath.row,
      splitPos: &splitPos
    )
  }
  
  private func _split(
    at index: Int,
    splitPos: inout Int
    ) -> LayoutNode? {
    
    guard let (a, b) = split?.nodes else {
      return nil
    }
    
    if index == splitPos {
      return self
    }
    
    splitPos += 1
    
    return a._split(at: index, splitPos: &splitPos) ?? b._split(at: index, splitPos: &splitPos)
  }
  
  func node(at index: IndexPath) -> LayoutNode? {
    var pos: Int = 0
    return _node(at: index.row, pos: &pos)
  }
  
  private func _node(
    at index: Int,
    pos: inout Int
    ) -> LayoutNode? {
    
    if let (a, b) = split?.nodes {
      return a._node(at: index, pos: &pos) ??
        b._node(at: index, pos: &pos)
    }
    
    // no split, so may be we found our node
    if (pos == index) {
      return self;
    }
    
    // wrong index, going next
    pos += 1
    return nil
  }
  
  func numberOfSections() -> Int {
    return 1
  }
  
  func numberOfItemsIn(section: Int) -> Int {
    guard section == 0 else {
      return 0
    }
    
    return numberOfLeafs()
  }
  
  func numberOfLeafs() -> Int {
    if let (a, b) = split?.nodes {
      return a.numberOfLeafs() + b.numberOfLeafs()
    }
    return 1
  }
  
  func split(
    with b: LayoutNode,
    flow: LayoutFlow,
    at ratio: CGFloat
    ) {
    
    let a = LayoutNode(key: key)
    
    a.parent = self
    b.parent = self
    
    self.key = genNodeKey()
    
    let split = LayoutSplit(
      flow: flow,
      ratio: ratio,
      nodes: (a: a, b: b)
    )
    self.split = split
  }
  
  @objc public func insert(
    at indexPath: IndexPath,
    node n: LayoutNode,
    flow: LayoutFlow
    ) {
    
    guard indexPath.section == 0 else {
      return
    }
    
    if let pNode = node(at: indexPath) {
      pNode.split(with: n, flow: flow, at: 0.5)
    } else {
      self.split(with: n, flow: flow, at: 1.0)
    }
  }
  
  func remove(at indexPath: IndexPath) {
    guard
      indexPath.section == 0,
      let node = node(at: indexPath),
      let parent = node.parent,
      let (a, b) = parent.split?.nodes
      else {
        return
    }
    
    let key = a.key == node.key ? b.key : a.key
    parent.key = key
    parent.split = nil
  }
  
  func prepareAttrs(for frame: CGRect) {
    var pos: Int = 0
    var splitPos: Int = 0
    
    _prepareAttrs(
      for: frame,
      pos: &pos,
      splitPos: &splitPos
    )
  }
  
  private func _prepareAttrs(
    for frame: CGRect,
    pos: inout Int,
    splitPos: inout Int
    ) {
    
    guard let split = split else {
      attrs.indexPath.row = pos
      attrs.frame = frame
      pos += 1
      return
    }
    
    attrs.indexPath.row = splitPos
    
    let ratio = split.ratio
    var aFrame = frame
    var bFrame = frame
    
    let grip: CGFloat = 6
    let halfGrip: CGFloat = grip * 0.5
    let gripFrame: CGRect
    
    switch split.flow {
    case .column:
      aFrame.size.width = frame.width * ratio - halfGrip
      
      bFrame.origin.x = aFrame.maxX + grip
      bFrame.size.width = frame.width - aFrame.width - grip
      
      gripFrame = CGRect(
        x: aFrame.maxX,
        y: frame.origin.y,
        width: grip,
        height: frame.height
      )
    case .row:
      aFrame.size.height = frame.height * ratio - halfGrip
      
      bFrame.origin.y = aFrame.maxY + grip
      bFrame.size.height = frame.height - aFrame.height - grip
      
      gripFrame = CGRect(
        x: frame.origin.x,
        y: aFrame.maxY,
        width: frame.width,
        height: grip
      )
    }
    
    splitPos += 1
    attrs.frame = gripFrame
    
    let (a, b) = split.nodes
    
    a._prepareAttrs(for: aFrame, pos: &pos, splitPos: &splitPos)
    b._prepareAttrs(for: bFrame, pos: &pos, splitPos: &splitPos)
  }
  
  func fill(
    attributes: inout [LayoutAttrs],
    in rect: CGRect
    ) {
    
    if rect.intersects(attrs.frame) {
      attributes.append(attrs)
    }
    
    if let (a, b) = split?.nodes {
      a.fill(attributes: &attributes, in: rect)
      b.fill(attributes: &attributes, in: rect)
    }
  }
  
  func initialAttrs(at indexPath: IndexPath) -> LayoutAttrs? {
    guard let split = parent?.split
      else {
        return nil
    }
    
    let initialAttrs = LayoutAttrs(forCellWith: indexPath)
    
    initialAttrs.frame = split.nodes.a.attrs.frame
    initialAttrs.zIndex = -1

    return initialAttrs
  }
  
  func pathToRoot() -> [LayoutNode] {
    var path = [LayoutNode]()
    
    var n: LayoutNode? = self
    while let node = n {
      path.append(node)
      n = node.parent
    }
    return path
  }
  
  func commonParent(
    _ other: LayoutNode
    ) -> LayoutNode? {
    
    let pathA = pathToRoot().reversed()
    let pathB = other.pathToRoot().reversed()
    
    var result = pathA.first
    for (a, b) in zip(pathA , pathB) where a == b {
      result = a
    }
    return result
  }
}

public func genNodeKey() -> String {
  return ProcessInfo.processInfo.globallyUniqueString
}

extension LayoutNode {
  static func == (lhs: LayoutNode, rhs: LayoutNode) -> Bool {
    return lhs.key == rhs.key
  }
}
