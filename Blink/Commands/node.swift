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
import NodeMobile
import ios_system

@_cdecl("node_main")
func node_main(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
  guard let argv = argv else {
    return -1
  }

  // Compute byte size need for all arguments in contiguous memory.
  var cArgsSize = Int(argc)
  for i in 0..<Int(argc) {
    guard let arg = argv[i] else {
      return -1
    }
    
    cArgsSize += strlen(arg)
  }
  
  
  let stdinNO = fileno(thread_stdin)
  let stdoutNO = fileno(thread_stdout)
  let stderrNO = fileno(thread_stderr)
  let stdinTTY = ios_isatty(stdinNO)
  let stdoutTTY = ios_isatty(stdoutNO)
  let stderrTTY = ios_isatty(stderrNO)
  
  let blink_io_env = "\(stdinNO),\(stdoutNO),\(stderrNO),\(stdinTTY),\(stdoutTTY),\(stderrTTY)"
  print(blink_io_env)
  "BLINK_IO".withCString { name in
    _ = blink_io_env.withCString { value in
      setenv(name, value, 1)
    }
  }
  

  // Stores arguments in contiguous memory.
  guard let argsBuffer = calloc(cArgsSize, MemoryLayout<Int8>.size)?.assumingMemoryBound(to: Int8.self) // UnsafeMutablePointer<Int8>.allocate(capacity: cArgsSize)
  else {
    return -1
  }
  
  defer {
    argsBuffer.deallocate()
  }
  
  //argv to pass into node.
  let nodeArgv = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: Int(argc))
  defer {
    nodeArgv.deallocate()
  }
  
  var currentArgsPosition = argsBuffer
  
  for i in 0..<Int(argc) {
    guard let arg = argv[i] else {
      return -1
    }
    
    let len = strlen(arg)
    strncpy(currentArgsPosition, arg, len)
    nodeArgv[i] = currentArgsPosition
    currentArgsPosition = currentArgsPosition.advanced(by: len + 1)
  }
  
  return node_start(argc, nodeArgv)
}
