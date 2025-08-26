// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.0;

interface L2GovRelayLike {
    function l1GovernanceRelay() external view returns (address);
    function messenger() external view returns (address);
}

interface L2TokenBridgeLike {
    function isOpen() external view returns (uint256);
    function otherBridge() external view returns (address);
    function messenger() external view returns (address);
    function version() external view returns (string memory);
    function getImplementation() external view returns (address);
    function upgradeToAndCall(address, bytes memory) external;
    function rely(address) external;
    function deny(address) external;
    function close() external;
    function registerToken(address, address) external;
    function setMaxWithdraw(address, uint256) external;
}

interface AuthLike {
    function rely(address usr) external;
}

// A reusable L2 spell to be used by the L2GovernanceRelay to exert admin control over L2TokenBridge
contract L2TokenBridgeSpell {
    L2TokenBridgeLike public immutable l2Bridge;

    constructor(address l2Bridge_) {
        l2Bridge = L2TokenBridgeLike(l2Bridge_);
    }

    function upgradeToAndCall(address newImp, bytes memory data) external { l2Bridge.upgradeToAndCall(newImp, data); }
    function rely(address usr) external { l2Bridge.rely(usr); }
    function deny(address usr) external { l2Bridge.deny(usr); }
    function close() external { l2Bridge.close(); }

    function registerTokens(address[] memory l1Tokens, address[] memory l2Tokens) public { 
        for (uint256 i; i < l2Tokens.length;) {
            l2Bridge.registerToken(l1Tokens[i], l2Tokens[i]);
            AuthLike(l2Tokens[i]).rely(address(l2Bridge));
            unchecked { ++i; }
        }
    }

    function setMaxWithdraws(address[] memory l2Tokens, uint256[] memory maxWithdraws) public { 
        for (uint256 i; i < l2Tokens.length;) {
            l2Bridge.setMaxWithdraw(l2Tokens[i], maxWithdraws[i]);
            unchecked { ++i; }
        }
    }

    function init(
        address l2GovRelay_,
        address l2Bridge_,
        address l2BridgeImp,
        address l1GovRelay,
        address l1Bridge,
        address l2Messenger,
        address[] calldata l1Tokens,
        address[] calldata l2Tokens,
        uint256[] calldata maxWithdraws
    ) external {
        L2GovRelayLike l2GovRelay = L2GovRelayLike(l2GovRelay_);

        // sanity checks
        require(address(l2Bridge) == l2Bridge_, "L2TokenBridgeSpell/l2-bridge-mismatch");
        require(keccak256(bytes(l2Bridge.version())) == keccak256("1"), "L2TokenBridgeSpell/version-does-not-match");
        require(l2Bridge.getImplementation() == l2BridgeImp, "L2TokenBridgeSpell/imp-does-not-match");
        require(l2Bridge.isOpen() == 1, "L2TokenBridgeSpell/not-open");
        require(l2Bridge.otherBridge() == l1Bridge, "L2TokenBridgeSpell/other-bridge-mismatch");
        require(l2Bridge.messenger() == l2Messenger, "L2TokenBridgeSpell/l2-bridge-messenger-mismatch");
        require(l2GovRelay.l1GovernanceRelay() == l1GovRelay, "L2TokenBridgeSpell/l1-gov-relay-mismatch");
        require(l2GovRelay.messenger() == l2Messenger, "L2TokenBridgeSpell/l2-gov-relay-messenger-mismatch");

        registerTokens(l1Tokens, l2Tokens);
        setMaxWithdraws(l2Tokens, maxWithdraws);
    }
}
