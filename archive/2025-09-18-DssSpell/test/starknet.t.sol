// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>
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

pragma solidity 0.8.16;

import "../DssSpell.t.base.sol";

contract ConfigStarknet {
    StarknetValues starknetValues;

    struct StarknetValues {
        bytes32 l2_spell;
        address core_implementation;
        uint256 dai_bridge_isOpen;
        uint256 dai_bridge_ceiling;
        uint256 dai_bridge_maxDeposit;
        uint256 l2_dai_bridge;
        uint256 l2_gov_relay;
        uint256 relay_selector;
    }

    function setStarknetValues() public {
        uint256 WAD = 10 ** 18;

        starknetValues = StarknetValues({
            l2_spell:                  0, // Set to zero if no spell is set.
            core_implementation:       0x2793010E6711Acd5C46ed17f2183a9d58db71e04, // As of 2025-03-02
            dai_bridge_isOpen:         0, // 1 open, 0 closed
            dai_bridge_ceiling:        5_000_000 * WAD, // wei
            dai_bridge_maxDeposit:     type(uint256).max, // wei
            l2_dai_bridge:             0x075ac198e734e289a6892baa8dd14b21095f13bf8401900f5349d5569c3f6e60,
            l2_gov_relay:              0x05f4d9b039f82e9a90125fb119ace0531f4936ff2a9a54a8598d49a4cd4bd6db,
            relay_selector:            300224956480472355485152391090755024345070441743081995053718200325371913697 // Hardcoded in L1 gov relay, not public
        });
    }
}

interface StarknetEscrowMomLike {
    function owner() external returns (address);
    function authority() external returns (address);
    function escrow() external returns (address);
    function token() external returns (address);
}

interface StarknetEscrowLike {
    function wards(address) external returns(uint256);
}

interface StarknetDaiBridgeLike {
    function wards(address) external returns(uint256);
    function isOpen() external returns (uint256);
    function ceiling() external returns (uint256);
    function maxDeposit() external returns (uint256);
    function dai() external returns (address);
    function starkNet() external returns (address);
    function escrow() external returns (address);
    function l2DaiBridge() external returns (uint256);
}

interface StarknetGovRelayLike {
    function wards(address) external returns (uint256);
    function starkNet() external returns (address);
    function l2GovernanceRelay() external returns (uint256);
}

interface StarknetCoreLike {
    function implementation() external returns (address);
    function isNotFinalized() external returns (bool);
    function l1ToL2Messages(bytes32) external returns (uint256);
    function l1ToL2MessageNonce() external returns (uint256);
}

interface DaiLike {
    function allowance(address, address) external view returns (uint256);
}

contract StarknetTests is DssSpellTestBase, ConfigStarknet {

    event LogMessageToL2(
            address indexed fromAddress,
            uint256 indexed toAddress,
            uint256 indexed selector,
            uint256[] payload,
            uint256 nonce,
            uint256 fee
        );

    constructor() {
        setStarknetValues();
    }

    function testStarknet() public {

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        _checkStarknetEscrowMom();
        _checkStarknetEscrow();
        _checkStarknetDaiBridge();
        _checkStarknetGovRelay();
        _checkStarknetCore();
    }

    function testStarknetSpell() public {

        if (starknetValues.l2_spell != bytes32(0)) {
            // Ensure the Pause Proxy has some ETH for the Starknet Spell
            assertGt(pauseProxy.balance, 0);
            _vote(address(spell));
            DssSpell(spell).schedule();

            vm.warp(DssSpell(spell).nextCastTime());

            vm.expectEmit(true, true, true, false, addr.addr("STARKNET_CORE"));
            emit LogMessageToL2(addr.addr("STARKNET_GOV_RELAY"), starknetValues.l2_gov_relay, starknetValues.relay_selector, _payload(starknetValues.l2_spell), 0, 0);
            DssSpell(spell).cast();

            assertTrue(spell.done());

            _checkStarknetMessage(starknetValues.l2_spell);
        }
    }

    function _checkStarknetEscrowMom() internal {
        StarknetEscrowMomLike escrowMom = StarknetEscrowMomLike(addr.addr("STARKNET_ESCROW_MOM"));

        assertEq(escrowMom.owner(),     addr.addr("MCD_PAUSE_PROXY"), "StarknetTest/pause-proxy-not-owner-on-escrow-mom");
        assertEq(escrowMom.authority(), addr.addr("MCD_ADM"),         "StarknetTest/chief-not-authority-on-escrow-mom");
        assertEq(escrowMom.escrow(),    addr.addr("STARKNET_ESCROW"), "StarknetTest/unexpected-escrow-on-escrow-mom");
        assertEq(escrowMom.token(),     addr.addr("MCD_DAI"),         "StarknetTest/unexpected-dai-on-escrow-mom");
    }

    function _checkStarknetEscrow() internal {
        StarknetEscrowLike escrow = StarknetEscrowLike(addr.addr("STARKNET_ESCROW"));

        assertEq(escrow.wards(addr.addr("MCD_PAUSE_PROXY")),     1, "StarknetTest/pause-proxy-not-ward-on-escrow");
        assertEq(escrow.wards(addr.addr("MCD_ESM")),             1, "StarknetTest/esm-not-ward-on-escrow");
        assertEq(escrow.wards(addr.addr("STARKNET_ESCROW_MOM")), 1, "StarknetTest/escrow-mom-not-ward-on-escrow");

        DaiLike dai = DaiLike(addr.addr("MCD_DAI"));

        assertEq(dai.allowance(addr.addr("STARKNET_ESCROW"), addr.addr("STARKNET_DAI_BRIDGE")), type(uint256).max, "StarknetTest/unexpected-escrow-allowance");
        assertEq(dai.allowance(addr.addr("STARKNET_ESCROW"), addr.addr("STARKNET_DAI_BRIDGE_LEGACY")), 0, "StarknetTest/unexpected-legacy-escrow-allowance");
    }

    function _checkStarknetDaiBridge() internal {
        StarknetDaiBridgeLike daiBridge = StarknetDaiBridgeLike(addr.addr("STARKNET_DAI_BRIDGE"));

        assertEq(daiBridge.isOpen(),     starknetValues.dai_bridge_isOpen,     "StarknetTestError/dai-bridge-isOpen-unexpected");
        assertEq(daiBridge.ceiling(),    starknetValues.dai_bridge_ceiling,    "StarknetTestError/dai-bridge-ceiling-unexpected");
        assertEq(daiBridge.maxDeposit(), starknetValues.dai_bridge_maxDeposit, "StarknetTestError/dai-bridge-maxDeposit-unexpected");

        assertEq(daiBridge.dai(),      addr.addr("MCD_DAI"),         "StarknetTest/dai-bridge-dai");
        assertEq(daiBridge.starkNet(), addr.addr("STARKNET_CORE"),   "StarknetTest/dai-bridge-core");
        assertEq(daiBridge.escrow(),   addr.addr("STARKNET_ESCROW"), "StarknetTest/dai-bridge-escrow");

        assertEq(daiBridge.wards(addr.addr("MCD_PAUSE_PROXY")), 1, "StarknetTest/pause-proxy-not-ward-on-dai-bridge");
        assertEq(daiBridge.wards(addr.addr("MCD_ESM")),         1, "StarknetTest/esm-not-ward-on-dai-bridge");

        assertEq(daiBridge.l2DaiBridge(), starknetValues.l2_dai_bridge, "StarknetTest/wrong-l2-dai-bridge-on-dai-bridge");
    }

    function _checkStarknetGovRelay() internal {
        StarknetGovRelayLike govRelay = StarknetGovRelayLike(addr.addr("STARKNET_GOV_RELAY"));

        assertEq(govRelay.wards(addr.addr("MCD_PAUSE_PROXY")), 1, "StarknetTest/pause-proxy-not-ward-on-gov-relay");
        assertEq(govRelay.wards(addr.addr("MCD_ESM")),         1, "StarknetTest/esm-not-ward-on-gov-relay");

        assertEq(govRelay.starkNet(), addr.addr("STARKNET_CORE"), "StarknetTest/unexpected-starknet-core-on-gov-relay");
        assertEq(govRelay.l2GovernanceRelay(), starknetValues.l2_gov_relay, "StarknetTest/unexpected-l2-gov-relay-on-gov-relay");
    }

    function _checkStarknetCore() internal {
        StarknetCoreLike core = StarknetCoreLike(addr.addr("STARKNET_CORE"));

        // Checks to see that starknet core implementation matches core
        //   If the core implementation changes, inspect the new implementation for safety and update the config
        //   Note: message checks may fail if the message structure changes in the new implementation
        assertEq(core.implementation(), starknetValues.core_implementation, _concat("StarknetTest/new-core-implementation-", bytes32(uint256(uint160(core.implementation())))));

        assertTrue(core.isNotFinalized());
    }


    function _checkStarknetMessage(bytes32 _spell) internal {
        StarknetCoreLike core = StarknetCoreLike(addr.addr("STARKNET_CORE"));

        if (_spell != 0) {

            // Nonce increments each message, back up one
            uint256 _nonce = core.l1ToL2MessageNonce() - 1;

            // Hash of message created by Starknet Core
            bytes32 _message = _getL1ToL2MsgHash(addr.addr("STARKNET_GOV_RELAY"), starknetValues.l2_gov_relay, starknetValues.relay_selector, _payload(_spell), _nonce);

            // Assert message is scheduled, core returns 0 if not in message array
            assertTrue(core.l1ToL2Messages(_message) > 0, "StarknetTest/SpellNotQueued");
        }
    }

    function _payload(bytes32 _spell) internal pure returns (uint256[] memory) {
        // Payload must be array
        uint256[] memory payload_ = new uint256[](1);
        payload_[0] = uint256(_spell);
        return payload_;
    }

    // Modified version of internal getL1ToL2MsgHash in Starknet Core implementation
    function _getL1ToL2MsgHash(
                address sender,
                uint256 toAddress,
                uint256 selector,
                uint256[] memory payload,
                uint256 nonce
            ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    uint256(uint160(sender)),
                    toAddress,
                    nonce,
                    selector,
                    payload.length,
                    payload
                )
            );
    }
}
