//////////////////////////////////////////////////////////////////////////////////
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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///* Messages for the authentication agent connection. */
//#define SSH_AGENTC_REQUEST_RSA_IDENTITIES  1
//#define SSH_AGENT_RSA_IDENTITIES_ANSWER    2
//#define SSH_AGENTC_RSA_CHALLENGE    3
//#define SSH_AGENT_RSA_RESPONSE      4
//#define SSH_AGENT_FAILURE      5
//#define SSH_AGENT_SUCCESS      6
//#define SSH_AGENTC_ADD_RSA_IDENTITY    7
//#define SSH_AGENTC_REMOVE_RSA_IDENTITY    8
//#define SSH_AGENTC_REMOVE_ALL_RSA_IDENTITIES  9
//
///* private OpenSSH extensions for SSH2 */
//#define SSH2_AGENTC_REQUEST_IDENTITIES    11
//#define SSH2_AGENT_IDENTITIES_ANSWER    12
//#define SSH2_AGENTC_SIGN_REQUEST    13
//#define SSH2_AGENT_SIGN_RESPONSE    14
//#define SSH2_AGENTC_ADD_IDENTITY    17
//#define SSH2_AGENTC_REMOVE_IDENTITY    18
//#define SSH2_AGENTC_REMOVE_ALL_IDENTITIES  19
//
///* smartcard */
//#define SSH_AGENTC_ADD_SMARTCARD_KEY    20
//#define SSH_AGENTC_REMOVE_SMARTCARD_KEY    21
//
///* lock/unlock the agent */
//#define SSH_AGENTC_LOCK        22
//#define SSH_AGENTC_UNLOCK      23
//
///* add key with constraints */
//#define SSH_AGENTC_ADD_RSA_ID_CONSTRAINED  24
//#define SSH2_AGENTC_ADD_ID_CONSTRAINED    25
//#define SSH_AGENTC_ADD_SMARTCARD_KEY_CONSTRAINED 26
//
//#define  SSH_AGENT_CONSTRAIN_LIFETIME    1
//#define  SSH_AGENT_CONSTRAIN_CONFIRM    2
//#define  SSH_AGENT_CONSTRAIN_MAXSIGN    3
//
///* extended failure messages */
//#define SSH2_AGENT_FAILURE      30
//
///* additional error code for ssh.com's ssh-agent2 */
//#define SSH_COM_AGENT2_FAILURE      102
//
//#define  SSH_AGENT_OLD_SIGNATURE      0x01
//#define  SSH_AGENT_RSA_SHA2_256      0x02
//#define  SSH_AGENT_RSA_SHA2_512      0x04

@interface SSHAgent : NSObject

@end

NS_ASSUME_NONNULL_END
