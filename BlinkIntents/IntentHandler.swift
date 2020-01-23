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
// In addition, Blink is also subject to certain additional terms underIntentHandling
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


import Intents
import ios_system

class IntentHandler: INExtension, RunCmdIntentHandling {
  private let _queue = DispatchQueue(label: "cmd")
  private let _termDevice: TermDevice
  private let _mcpSession: MCPSession
  
  override init() {
    _termDevice = TermDevice()
    _mcpSession = MCPSession(device: _termDevice, andParams: nil)

    super.init()
    
  }
  
  
  func handle(intent: RunCmdIntent, completion: @escaping (RunCmdIntentResponse) -> Void) {
    
    let cmd = intent.cmdLine ?? "help"
    
    
    let tmpFile = BlinkPaths.blinkURL()!.appendingPathComponent(UUID().uuidString).path
    
    _mcpSession.enqueueCommand("\(cmd) > \(tmpFile)")
    
    
    _mcpSession.cmdQueue?.async {
      let response = RunCmdIntentResponse(code: .success, userActivity: nil)
      let result = (try? String(contentsOfFile: tmpFile)) ?? ""
      response.stdOut = result
      completion(response)
    }
  }
  
  func resolveCmdLine(for intent: RunCmdIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
    completion(.success(with: "help"))
  }
  
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
}
