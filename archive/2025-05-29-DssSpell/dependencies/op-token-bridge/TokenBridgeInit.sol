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

import { DssInstance } from "dss-test/MCD.sol";
import { L1TokenBridgeInstance } from "./L1TokenBridgeInstance.sol";
import { L2TokenBridgeInstance } from "./L2TokenBridgeInstance.sol";
import { L2TokenBridgeSpell } from "./L2TokenBridgeSpell.sol";

interface L1TokenBridgeLike {
    function l1ToL2Token(address) external view returns (address);
    function isOpen() external view returns (uint256);
    function otherBridge() external view returns (address);
    function messenger() external view returns (address);
    function version() external view returns (string memory);
    function getImplementation() external view returns (address);
    function file(bytes32, address) external;
    function registerToken(address, address) external;
}

interface L1RelayLike {
    function l2GovernanceRelay() external view returns (address);
    function messenger() external view returns (address);
    function relay(
        address target,
        bytes calldata targetData,
        uint32 minGasLimit
    ) external;
}

interface EscrowLike {
    function approve(address, address, uint256) external;
}

struct BridgesConfig {
    address l1Messenger;
    address l2Messenger;
    address[] l1Tokens;
    address[] l2Tokens;
    uint256[] maxWithdraws;
    uint32 minGasLimit;
    bytes32 govRelayCLKey;
    bytes32 escrowCLKey;
    bytes32 l1BridgeCLKey;
    bytes32 l1BridgeImpCLKey;
}

library TokenBridgeInit {
    function initBridges(
        DssInstance memory           dss,
        L1TokenBridgeInstance memory l1BridgeInstance,
        L2TokenBridgeInstance memory l2BridgeInstance,
        BridgesConfig memory         cfg
    ) internal {
        L1RelayLike     l1GovRelay = L1RelayLike(l1BridgeInstance.govRelay);
        EscrowLike          escrow = EscrowLike(l1BridgeInstance.escrow);
        L1TokenBridgeLike l1Bridge = L1TokenBridgeLike(l1BridgeInstance.bridge);

        // sanity checks
        require(keccak256(bytes(l1Bridge.version())) == keccak256("1"), "TokenBridgeInit/version-does-not-match");
        require(l1Bridge.getImplementation() == l1BridgeInstance.bridgeImp, "TokenBridgeInit/imp-does-not-match");
        require(l1Bridge.isOpen() == 1, "TokenBridgeInit/not-open");
        require(l1Bridge.otherBridge() == l2BridgeInstance.bridge, "TokenBridgeInit/other-bridge-mismatch");
        require(l1Bridge.messenger() == cfg.l1Messenger, "TokenBridgeInit/l1-bridge-messenger-mismatch");
        require(l1GovRelay.l2GovernanceRelay() == l2BridgeInstance.govRelay, "TokenBridgeInit/l2-gov-relay-mismatch");
        require(l1GovRelay.messenger() == cfg.l1Messenger, "TokenBridgeInit/l1-gov-relay-messenger-mismatch");
        require(cfg.l1Tokens.length == cfg.l2Tokens.length, "TokenBridgeInit/token-arrays-mismatch");
        require(cfg.maxWithdraws.length == cfg.l2Tokens.length, "TokenBridgeInit/max-withdraws-length-mismatch");
        require(cfg.minGasLimit <= 1_000_000_000, "TokenBridgeInit/min-gas-limit-out-of-bounds");

        l1Bridge.file("escrow", address(escrow));

        for (uint256 i; i < cfg.l1Tokens.length; ++i) {
            (address l1Token, address l2Token) = (cfg.l1Tokens[i], cfg.l2Tokens[i]);
            require(l1Token != address(0), "TokenBridgeInit/invalid-l1-token");
            require(l2Token != address(0), "TokenBridgeInit/invalid-l2-token");
            require(cfg.maxWithdraws[i] > 0, "TokenBridgeInit/max-withdraw-not-set");
            require(l1Bridge.l1ToL2Token(l1Token) == address(0), "TokenBridgeInit/existing-l1-token");

            l1Bridge.registerToken(l1Token, l2Token);
            escrow.approve(l1Token, address(l1Bridge), type(uint256).max);
        }

        l1GovRelay.relay({
            target:      l2BridgeInstance.spell,
            targetData:  abi.encodeCall(L2TokenBridgeSpell.init, (
                l2BridgeInstance.govRelay,
                l2BridgeInstance.bridge,
                l2BridgeInstance.bridgeImp,
                address(l1GovRelay),
                address(l1Bridge),
                cfg.l2Messenger,
                cfg.l1Tokens,
                cfg.l2Tokens,
                cfg.maxWithdraws
            )),
            minGasLimit: cfg.minGasLimit
        });

        dss.chainlog.setAddress(cfg.govRelayCLKey,    address(l1GovRelay));
        dss.chainlog.setAddress(cfg.escrowCLKey,      address(escrow));
        dss.chainlog.setAddress(cfg.l1BridgeCLKey,    address(l1Bridge));
        dss.chainlog.setAddress(cfg.l1BridgeImpCLKey, l1BridgeInstance.bridgeImp);
    }
}
