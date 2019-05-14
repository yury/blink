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

public class LayoutCell: UICollectionViewCell {
  
  var _controller: UIViewController? = nil
  
  @objc public func set(controller: UIViewController, parent: UIViewController) {
    _controller = controller;
    controller.willMove(toParent: parent)
    contentView.addSubview(controller.view)
    parent.addChild(controller)
    controller.didMove(toParent: parent)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    _controller?.view.frame = contentView.bounds
  }
  
  public override func prepareForReuse() {
    super.prepareForReuse()
    _controller?.willMove(toParent: nil)
    _controller?.view.removeFromSuperview()
    _controller?.removeFromParent()
  }
}

