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

public class CollectionViewSplitLayout: UICollectionViewLayout {
  var root: LayoutNode
  
  init(root: LayoutNode) {
    self.root = root
    super.init()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override public func prepare() {
    super.prepare()
    var bounds = collectionView?.bounds ?? CGRect.zero
    root.prepareAttrs(for: bounds)
  }
  
  override public var collectionViewContentSize: CGSize {
    guard let view = collectionView else {
      return .zero
    }
    let bounds = view.bounds
    return bounds.size
  }
  
  override public func shouldInvalidateLayout(
    forBoundsChange newBounds: CGRect
    ) -> Bool {
    return collectionView?.bounds.width != newBounds.width
  }
  
  override public func layoutAttributesForElements(
    in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
    var attributes = [LayoutAttrs]()
    root.fill(attributes: &attributes, in: rect)
    return attributes
  }
  
  override public func layoutAttributesForItem(
    at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
    return root.node(at: indexPath)?.attrs
  }
  
  override public func layoutAttributesForSupplementaryView(
    ofKind elementKind: String,
    at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
    return root.split(at: indexPath)?.attrs
  }
  
  override public func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return root.node(at: itemIndexPath)?.initialAttrs(at: itemIndexPath)
  }
}
