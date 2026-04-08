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

// --- LZ interfaces ---
// Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol
interface ILZEndpoint {
    function eid() external view returns (uint32);
    function delegates(address) external view returns (address);
    function getSendLibrary(address, uint32) external view returns (address);
    function getReceiveLibrary(address, uint32) external view returns (address, bool);
    function getConfig(address, address, uint32, uint32) external view returns (bytes memory);
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

// Source: https://github.com/sky-ecosystem/sky-oapp-oft/blob/5ad5cb6bbe624e2b1cb99acfe3e4140fa1c233b9/contracts/SkyOFTCore.sol
interface ILZOApp {
    function owner() external view returns (address);
    function endpoint() external view returns (address);
    function peers(uint32 eid) external view returns (bytes32);
}

interface ILZOFTAdapter is ILZOApp {
    function token() external view returns (address);
    function paused() external view returns (bool);
    function pausers(address) external view returns (bool);
    function enforcedOptions(uint32 eid, uint16 msgType) external view returns (bytes memory);
    function outboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
    function inboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
}

struct UlnConfig {
    uint64  confirmations;
    uint8   requiredDVNCount;
    uint8   optionalDVNCount;
    uint8   optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

struct ExecutorConfig {
    uint32  maxMessageSize;
    address executor;
}

struct Origin {
    uint32  srcEid;
    bytes32 sender;
    uint64  nonce;
}

struct LZBridge {
    uint256 forkId;
    address endpoint;
    address receiveLib;
}

/// @title  LZBridgeTesting
/// @notice Self-contained helper for relaying LayerZero V2 messages between two forked chains in Foundry tests.
/// @dev    Adapted from Spark's xchain-helpers (see link above). All LZ dependencies are inlined to avoid
///         adding external submodules.
///
///         Usage:
///         1. Create an LZBridge for the destination chain.
///         2. On the source fork: perform actions that emit PacketSent events from the LZ endpoint.
///         3. Call `vm.recordLogs()` before the actions and `vm.getRecordedLogs()` after.
///         4. Call `relayMessagesToDestination(bridge, logs, srcEndpoint, sender, receiver)`.
///            This handles fork switching, message relay, and restores the source fork.

/// @notice Parameters for verifying OApp configuration (peer, libraries, DVN configs).
/// @dev    Adapted from https://github.com/sky-ecosystem/wh-lz-migration/blob/2c16517aab011ba32ed6f1b5977b888d2a6a753f/deploy/MigrationInit.sol#L130-L151
struct OAppConfig {
    address oapp;
    address endpoint;
    address owner;
    uint32  remoteEid;
    bytes32 peer;
    address sendLib;
    address recvLib;
    uint64  sendConfirmations;
    uint8   sendRequiredDVNCount;
    uint8   sendOptionalDVNCount;
    uint8   sendOptionalDVNThreshold;
    address[] sendRequiredDVNs;
    address[] sendOptionalDVNs;
    uint32  sendMaxMessageSize;
    address sendExecutor;
    uint64  recvConfirmations;
    uint8   recvRequiredDVNCount;
    uint8   recvOptionalDVNCount;
    uint8   recvOptionalDVNThreshold;
    address[] recvRequiredDVNs;
    address[] recvOptionalDVNs;
}

/// @notice Additional parameters for verifying OFT adapter configuration.
struct OFTAdapterConfig {
    address token;
    bool    paused;
    address pauser;
    uint48  outboundWindow;
    uint256 outboundLimit;
    uint48  inboundWindow;
    uint256 inboundLimit;
    bytes   enforcedOptionsSend;
    bytes   enforcedOptionsSendAndCall;
}

library LZBridgeTesting {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant PACKET_SENT_TOPIC = keccak256("PacketSent(bytes,bytes,address)");

    // --- Sanity check helpers ---

    /// @notice Verify OApp configuration (peer, endpoint, delegate, libraries, DVN configs).
    function checkOAppConfig(OAppConfig memory cfg) internal view {
        ILZOApp oapp = ILZOApp(cfg.oapp);

        require(oapp.owner()              == cfg.owner,    "LZBridgeTesting/owner-mismatch");
        require(oapp.endpoint()           == cfg.endpoint, "LZBridgeTesting/endpoint-mismatch");
        require(oapp.peers(cfg.remoteEid) == cfg.peer,     "LZBridgeTesting/peer-mismatch");
        require(
            ILZEndpoint(cfg.endpoint).delegates(cfg.oapp) == cfg.owner,
            "LZBridgeTesting/delegate-mismatch"
        );

        // Send library
        require(
            ILZEndpoint(cfg.endpoint).getSendLibrary(cfg.oapp, cfg.remoteEid) == cfg.sendLib,
            "LZBridgeTesting/send-library-mismatch"
        );

        // Receive library (skip if recvLib is address(0), e.g. for send-only OApps)
        if (cfg.recvLib != address(0)) {
            (address lib,) = ILZEndpoint(cfg.endpoint).getReceiveLibrary(cfg.oapp, cfg.remoteEid);
            require(lib == cfg.recvLib, "LZBridgeTesting/recv-library-mismatch");
        }

        // Send executor config (configType 1)
        {
            bytes memory raw = ILZEndpoint(cfg.endpoint).getConfig(cfg.oapp, cfg.sendLib, cfg.remoteEid, 1);
            ExecutorConfig memory exec = abi.decode(raw, (ExecutorConfig));
            require(exec.maxMessageSize == cfg.sendMaxMessageSize, "LZBridgeTesting/send-max-msg-size-mismatch");
            require(exec.executor       == cfg.sendExecutor,       "LZBridgeTesting/send-executor-mismatch");
        }

        // Send ULN config (configType 2)
        _checkUlnConfig(
            cfg.endpoint, cfg.oapp, cfg.sendLib, cfg.remoteEid,
            cfg.sendConfirmations, cfg.sendRequiredDVNCount, cfg.sendOptionalDVNCount,
            cfg.sendOptionalDVNThreshold, cfg.sendRequiredDVNs, cfg.sendOptionalDVNs,
            "send"
        );

        // Receive ULN config (configType 2) - skip if no receive library
        if (cfg.recvLib != address(0)) {
            _checkUlnConfig(
                cfg.endpoint, cfg.oapp, cfg.recvLib, cfg.remoteEid,
                cfg.recvConfirmations, cfg.recvRequiredDVNCount, cfg.recvOptionalDVNCount,
                cfg.recvOptionalDVNThreshold, cfg.recvRequiredDVNs, cfg.recvOptionalDVNs,
                "recv"
            );
        }
    }

    /// @notice Verify OFT adapter-specific settings (token, pauser, rate limits, enforced options).
    function checkOFTAdapterConfig(address oapp, uint32 remoteEid, OFTAdapterConfig memory cfg) internal view {
        ILZOFTAdapter oft = ILZOFTAdapter(oapp);

        require(oft.token()  == cfg.token,  "LZBridgeTesting/token-mismatch");
        require(oft.paused() == cfg.paused, "LZBridgeTesting/paused-mismatch");

        if (cfg.pauser != address(0)) {
            require(oft.pausers(cfg.pauser), "LZBridgeTesting/pauser-not-set");
        }

        // Rate limits
        {
            (,uint48 outW,, uint256 outL) = oft.outboundRateLimits(remoteEid);
            (,uint48  inW,, uint256  inL) = oft.inboundRateLimits(remoteEid);
            require(outW == cfg.outboundWindow, "LZBridgeTesting/outbound-window-mismatch");
            require(outL == cfg.outboundLimit,  "LZBridgeTesting/outbound-limit-mismatch");
            require(inW  == cfg.inboundWindow,  "LZBridgeTesting/inbound-window-mismatch");
            require(inL  == cfg.inboundLimit,   "LZBridgeTesting/inbound-limit-mismatch");
        }

        // Enforced options
        if (cfg.enforcedOptionsSend.length > 0) {
            bytes memory send = oft.enforcedOptions(remoteEid, 1);
            require(
                keccak256(send) == keccak256(cfg.enforcedOptionsSend),
                "LZBridgeTesting/enforced-options-send-mismatch"
            );
        }
        if (cfg.enforcedOptionsSendAndCall.length > 0) {
            bytes memory sendAndCall = oft.enforcedOptions(remoteEid, 2);
            require(
                keccak256(sendAndCall) == keccak256(cfg.enforcedOptionsSendAndCall),
                "LZBridgeTesting/enforced-options-send-and-call-mismatch"
            );
        }
    }

    function _checkUlnConfig(
        address endpoint, address oapp, address lib, uint32 eid,
        uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount,
        uint8 optionalDVNThreshold, address[] memory requiredDVNs, address[] memory optionalDVNs,
        string memory direction
    ) private view {
        bytes memory raw = ILZEndpoint(endpoint).getConfig(oapp, lib, eid, 2);
        UlnConfig memory cfg = abi.decode(raw, (UlnConfig));
        require(cfg.confirmations        == confirmations,        _err(direction, "confirmations-mismatch"));
        require(cfg.requiredDVNCount     == requiredDVNCount,     _err(direction, "required-dvn-count-mismatch"));
        require(cfg.optionalDVNCount     == optionalDVNCount,     _err(direction, "optional-dvn-count-mismatch"));
        require(cfg.optionalDVNThreshold == optionalDVNThreshold, _err(direction, "optional-dvn-threshold-mismatch"));
        require(cfg.requiredDVNs.length  == requiredDVNs.length,  _err(direction, "required-dvns-length-mismatch"));
        for (uint256 i = 0; i < requiredDVNs.length; i++) {
            require(cfg.requiredDVNs[i] == requiredDVNs[i], _err(direction, "required-dvn-mismatch"));
        }
        require(cfg.optionalDVNs.length == optionalDVNs.length, _err(direction, "optional-dvns-length-mismatch"));
        for (uint256 i = 0; i < optionalDVNs.length; i++) {
            require(cfg.optionalDVNs[i] == optionalDVNs[i], _err(direction, "optional-dvn-mismatch"));
        }
    }

    function _err(string memory direction, string memory message) private pure returns (string memory) {
        return string.concat("LZBridgeTesting/", direction, "-", message);
    }

    // --- Encoding helpers ---

    /// @notice Encode enforced options for lzReceive, replicating OptionsBuilder.addExecutorLzReceiveOption.
    /// @dev    See https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol
    function buildEnforcedOptions(uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
        uint16 TYPE_3          = 3;
        uint8  WORKER_ID       = 1; // Executor
        uint8  OPTION_TYPE     = 1; // LZRECEIVE
        if (_value == 0) {
            // option_length = 1 (optionType) + 16 (uint128 gas) = 17
            return abi.encodePacked(TYPE_3, WORKER_ID, uint16(17), OPTION_TYPE, _gas);
        } else {
            // option_length = 1 (optionType) + 16 (uint128 gas) + 16 (uint128 value) = 33
            return abi.encodePacked(TYPE_3, WORKER_ID, uint16(33), OPTION_TYPE, _gas, _value);
        }
    }

    // --- Relay helpers ---

    /// @notice Relay LZ messages to a destination chain fork and switch back to the source fork.
    /// @param bridge          Destination chain bridge config (forkId, endpoint, receiveLib)
    /// @param logs            Recorded Vm.Log entries (from vm.getRecordedLogs())
    /// @param srcEndpoint     LayerZero EndpointV2 address on the source chain
    /// @param sender          OApp sender address on the source chain
    /// @param receiver        OApp receiver address on the destination chain
    function relayMessagesToDestination(
        LZBridge memory bridge,
        Vm.Log[] memory logs,
        address srcEndpoint,
        address sender,
        address receiver
    ) internal {
        vm.selectFork(bridge.forkId);
        _relayMessages(logs, srcEndpoint, bridge.endpoint, bridge.receiveLib, sender, receiver);
    }

    /// @notice Relay LZ messages captured in logs from source chain to the current (destination) fork.
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
