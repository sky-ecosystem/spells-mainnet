// SPDX-FileCopyrightText: © 2020 Dai Foundation <www.daifoundation.org>
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

// Low-level LayerZero V2 packet relay mechanics.
// This helper owns only packet parsing and message delivery between forked chains.
// Higher-level lane structs, assertions, and fork orchestration live in LZLaneTesting.sol.
//
// Adapted from:
//   - Spark xchain-helpers LZBridgeTesting: https://github.com/sparkdotfi/xchain-helpers/blob/ca21bab97743e067f60dd1ef750c0e8af01ac4ca/src/testing/bridges/LZBridgeTesting.sol
//   - LayerZero PacketV1Codec: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/protocol/contracts/messagelib/libs/PacketV1Codec.sol

import {Vm} from "forge-std/Vm.sol";

// --- Packet parsing helper ---
// Byte offsets derived from the LayerZero V2 packet format specification.
contract PacketBytesHelper {
    uint256 private constant NONCE_OFFSET     = 1;
    uint256 private constant SRC_EID_OFFSET   = 9;
    uint256 private constant SENDER_OFFSET    = 13;
    uint256 private constant DST_EID_OFFSET   = 45;
    uint256 private constant RECEIVER_OFFSET  = 49;
    uint256 private constant GUID_OFFSET      = 81;
    uint256 private constant MESSAGE_OFFSET   = 113;

    function nonce(bytes calldata _packet) external pure returns (uint64) {
        return uint64(bytes8(_packet[NONCE_OFFSET:SRC_EID_OFFSET]));
    }

    function srcEid(bytes calldata _packet) external pure returns (uint32) {
        return uint32(bytes4(_packet[SRC_EID_OFFSET:SENDER_OFFSET]));
    }

    function dstEid(bytes calldata _packet) external pure returns (uint32) {
        return uint32(bytes4(_packet[DST_EID_OFFSET:RECEIVER_OFFSET]));
    }

    function guid(bytes calldata _packet) external pure returns (bytes32) {
        return bytes32(_packet[GUID_OFFSET:MESSAGE_OFFSET]);
    }

    function message(bytes calldata _packet) external pure returns (bytes memory) {
        return bytes(_packet[MESSAGE_OFFSET:]);
    }
}

// --- Minimal LZ Endpoint interface for relay ---

struct Origin {
    uint32  srcEid;
    bytes32 sender;
    uint64  nonce;
}

interface ILZEndpoint {
    function eid() external view returns (uint32);
    function verify(
        Origin calldata _origin,
        address         _receiver,
        bytes32         _payloadHash
    ) external;
    function lzReceive(
        Origin calldata _origin,
        address         _receiver,
        bytes32         _guid,
        bytes calldata  _message,
        bytes calldata  _extraData
    ) external payable;
}

/// @title  LZBridgeTesting
/// @notice Low-level helper for relaying LayerZero V2 messages between two forked chains.
/// @dev    Switches to the destination fork and delivers messages. Does NOT restore the source fork.
///         Use LZLaneTesting.relayToFork() for fork-restoring behavior.
library LZBridgeTesting {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant PACKET_SENT_TOPIC = keccak256("PacketSent(bytes,bytes,address)");

    /// @notice Switch to the destination fork and relay LZ messages from recorded logs.
    function relayMessages(
        Vm.Log[] memory logs,
        uint256 destForkId,
        address srcEndpoint,
        address dstEndpoint,
        address dstReceiveLib,
        address sender,
        address receiver
    ) internal {
        vm.selectFork(destForkId);
        _relayMessages(logs, srcEndpoint, dstEndpoint, dstReceiveLib, sender, receiver);
    }

    function _relayMessages(
        Vm.Log[] memory logs,
        address srcEndpoint,
        address dstEndpoint,
        address dstReceiveLib,
        address sender,
        address receiver
    ) private {
        PacketBytesHelper helper = new PacketBytesHelper();

        uint32 dstEid = ILZEndpoint(dstEndpoint).eid();

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 0 || logs[i].topics[0] != PACKET_SENT_TOPIC) continue;
            if (logs[i].emitter != srcEndpoint) continue;

            (bytes memory encodedPacket,,) = abi.decode(logs[i].data, (bytes, bytes, address));

            if (helper.dstEid(encodedPacket) != dstEid) continue;

            bytes32 packetGuid   = helper.guid(encodedPacket);
            bytes memory message = helper.message(encodedPacket);
            uint32 packetSrcEid  = helper.srcEid(encodedPacket);
            uint64 packetNonce   = helper.nonce(encodedPacket);

            Origin memory origin = Origin({
                srcEid: packetSrcEid,
                sender: bytes32(uint256(uint160(sender))),
                nonce:  packetNonce
            });

            bytes32 payloadHash = keccak256(abi.encodePacked(packetGuid, message));

            vm.startPrank(dstReceiveLib);
            ILZEndpoint(dstEndpoint).verify(origin, receiver, payloadHash);
            vm.stopPrank();

            ILZEndpoint(dstEndpoint).lzReceive(origin, receiver, packetGuid, message, "");
        }
    }
}
