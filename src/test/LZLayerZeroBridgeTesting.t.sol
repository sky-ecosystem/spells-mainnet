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

// Self-contained LayerZero V2 bridge testing helper.
// Adapted from:
//   - Spark xchain-helpers LZBridgeTesting: https://github.com/sparkdotfi/xchain-helpers/blob/ca21bab97743e067f60dd1ef750c0e8af01ac4ca/src/testing/bridges/LZBridgeTesting.sol
//   - LayerZero PacketV1Codec: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/protocol/contracts/messagelib/libs/PacketV1Codec.sol

import {Vm} from "forge-std/Vm.sol";

// --- PacketV1Codec (inline) ---
// Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/protocol/contracts/messagelib/libs/PacketV1Codec.sol
// Note: calldata slicing requires a helper contract since libraries with internal calldata functions
//       cannot be called cross-contract. We use a helper contract pattern (same as Spark's PacketBytesHelper).
contract PacketBytesHelper {
    // Byte offsets from PacketV1Codec
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

// --- LZ Endpoint interface ---
// Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol
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

struct Origin {
    uint32  srcEid;
    bytes32 sender;
    uint64  nonce;
}

/// @title  LZBridgeTesting
/// @notice Self-contained helper for relaying LayerZero V2 messages between two forked chains in Foundry tests.
/// @dev    Adapted from Spark's xchain-helpers (see link above). All LZ dependencies are inlined to avoid
///         adding external submodules.
///
///         Usage:
///         1. On the source fork: perform actions that emit PacketSent events from the LZ endpoint.
///         2. Call `vm.recordLogs()` before the actions and `vm.getRecordedLogs()` after.
///         3. Switch to destination fork with `vm.selectFork(destForkId)`.
///         4. Call `relayLZMessages(logs, srcEndpoint, dstEndpoint, dstReceiveLib, sender, receiver)`.
library LZBridgeTesting {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant PACKET_SENT_TOPIC = keccak256("PacketSent(bytes,bytes,address)");

    /// @notice Relay LZ messages captured in logs from source chain to the current (destination) fork.
    /// @param logs            Recorded Vm.Log entries (from vm.getRecordedLogs())
    /// @param srcEndpoint     LayerZero EndpointV2 address on the source chain
    /// @param dstEndpoint     LayerZero EndpointV2 address on the destination chain
    /// @param dstReceiveLib   ReceiveUln302 address on the destination chain (used to prank verify())
    /// @param sender          OApp sender address on the source chain
    /// @param receiver        OApp receiver address on the destination chain
    function relayMessages(
        Vm.Log[] memory logs,
        address srcEndpoint,
        address dstEndpoint,
        address dstReceiveLib,
        address sender,
        address receiver
    ) internal {
        PacketBytesHelper helper = new PacketBytesHelper();

        uint32 dstEid = ILZEndpoint(dstEndpoint).eid();

        for (uint256 i = 0; i < logs.length; i++) {
            // Filter for PacketSent events from the source endpoint
            if (logs[i].topics.length == 0 || logs[i].topics[0] != PACKET_SENT_TOPIC) continue;
            if (logs[i].emitter != srcEndpoint) continue;

            // Decode the event data: (bytes encodedPacket, bytes options, address sendLibrary)
            (bytes memory encodedPacket,,) = abi.decode(logs[i].data, (bytes, bytes, address));

            // Only relay packets destined for this endpoint
            if (helper.dstEid(encodedPacket) != dstEid) continue;

            bytes32 packetGuid    = helper.guid(encodedPacket);
            bytes memory message  = helper.message(encodedPacket);
            uint32 packetSrcEid   = helper.srcEid(encodedPacket);
            uint64 packetNonce    = helper.nonce(encodedPacket);

            Origin memory origin = Origin({
                srcEid: packetSrcEid,
                sender: bytes32(uint256(uint160(sender))),
                nonce:  packetNonce
            });

            bytes32 payloadHash = keccak256(abi.encodePacked(packetGuid, message));

            // Step 1: Prank as the receive library to call verify() (bypasses DVN verification)
            vm.startPrank(dstReceiveLib);
            ILZEndpoint(dstEndpoint).verify(origin, receiver, payloadHash);
            vm.stopPrank();

            // Step 2: Call the permissionless lzReceive on the endpoint
            ILZEndpoint(dstEndpoint).lzReceive(origin, receiver, packetGuid, message, "");
        }
    }
}
