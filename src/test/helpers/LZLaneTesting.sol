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

// Shared lane structs, assertion helpers, option encoding, OFT send ceremony, and fork-aware relay.
// This is the higher-level helper that spell tests interact with directly.
// Low-level packet relay is delegated to LZBridgeTesting.

import {Vm} from "forge-std/Vm.sol";
import {LZBridgeTesting} from "./LZBridgeTesting.sol";

// --- Interfaces ---

interface ILZEndpointView {
    function delegates(address) external view returns (address);
    function getSendLibrary(address, uint32) external view returns (address);
    function getReceiveLibrary(address, uint32) external view returns (address, bool);
    function getConfig(address, address, uint32, uint32) external view returns (bytes memory);
}

interface ILZOApp {
    function owner() external view returns (address);
    function endpoint() external view returns (address);
    function peers(uint32 eid) external view returns (bytes32);
}

interface ILZOFTAdapter is ILZOApp {
    function defaultFeeBps() external view returns (uint16);
    function feeBps(uint32 dstEid) external view returns (uint16 feeBps, bool enabled);
    function token() external view returns (address);
    function paused() external view returns (bool);
    function pausers(address) external view returns (bool);
    function rateLimitAccountingType() external view returns (uint8);
    function enforcedOptions(uint32 eid, uint16 msgType) external view returns (bytes memory);
    function outboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
    function inboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
}

struct RateLimitConfig {
    uint32 eid;
    uint48 window;
    uint256 limit;
}

interface GovernanceOAppSenderLike is ILZOApp {
    function canCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget) external view returns (bool);
}

interface L1GovernanceRelayLike {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }
    function l1Oapp() external view returns (address);
    function relayEVM(
        uint32                dstEid,
        address               l2GovernanceRelay,
        address               target,
        bytes calldata        targetData,
        bytes calldata        extraOptions,
        MessagingFee calldata fee,
        address               refundAddress
    ) external payable;
}

interface SkyOFTAdapterLike is ILZOApp {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }
    struct MessagingReceipt {
        bytes32 guid;
        uint64  nonce;
        MessagingFee fee;
    }
    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }
    struct SendParam {
        uint32  dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes   extraOptions;
        bytes   composeMsg;
        bytes   oftCmd;
    }
    function enforcedOptions(uint32 eid, uint16 msgType) external view returns (bytes memory);
    function inboundRateLimits(uint32 dstEid) external view returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
    function pause() external;
    function paused() external view returns (bool);
    function pausers(address pauser) external view returns (bool canPause);
    function unpause() external;
    function quoteSend(SendParam memory _sendParam, bool _payInLzToken) external view returns (MessagingFee memory msgFee);
    function send(SendParam memory _sendParam, MessagingFee memory _fee, address _refundAddress)
        external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigsInbound, RateLimitConfig[] calldata _rateLimitConfigsOutbound) external;
    function token() external view returns (address);
    function outboundRateLimits(uint32 srcEid) external view returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
}

// --- Lane config structs ---

struct LzChainConfig {
    uint32  eid;
    address endpoint;
    address sendLib302;
    address recvLib302;     // address(0) for send-only OApps
}

struct LzExecutorConfig {
    uint32  maxMessageSize;
    address executor;
}

struct LzUlnConfig {
    uint64    confirmations;
    uint8     requiredDVNCount;
    uint8     optionalDVNCount;
    uint8     optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

struct LzLaneConfig {
    LzChainConfig    localChain;
    LzChainConfig    remoteChain;
    address          localOApp;
    address          remoteOApp;
    bytes32          remotePeer;
    LzExecutorConfig sendExecutor;
    LzExecutorConfig recvExecutor;
    LzUlnConfig      sendUln;
    LzUlnConfig      recvUln;
    bytes            enforcedOptions;
}

/// @title  LZLaneTesting
/// @notice Shared lane-level test helpers: config assertions, option encoding, OFT send ceremony, and fork-aware relay.
/// @dev    Spell tests use this layer. Low-level packet mechanics are in LZBridgeTesting.
library LZLaneTesting {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // --- Utility ---

    function toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    // --- Lane assertions ---

    function assertPeerSet(LzLaneConfig memory lane) internal view {
        require(
            ILZOApp(lane.localOApp).peers(lane.remoteChain.eid) == lane.remotePeer,
            "LZLaneTesting/peer-mismatch"
        );
    }

    function assertSendLibrary(LzLaneConfig memory lane) internal view {
        require(
            ILZEndpointView(lane.localChain.endpoint).getSendLibrary(lane.localOApp, lane.remoteChain.eid) == lane.localChain.sendLib302,
            "LZLaneTesting/send-library-mismatch"
        );
    }

    function assertReceiveLibrary(LzLaneConfig memory lane) internal view {
        if (lane.localChain.recvLib302 == address(0)) return;
        (address lib,) = ILZEndpointView(lane.localChain.endpoint).getReceiveLibrary(lane.localOApp, lane.remoteChain.eid);
        require(lib == lane.localChain.recvLib302, "LZLaneTesting/recv-library-mismatch");
    }

    function assertSendExecutor(LzLaneConfig memory lane) internal view {
        bytes memory raw = ILZEndpointView(lane.localChain.endpoint).getConfig(
            lane.localOApp, lane.localChain.sendLib302, lane.remoteChain.eid, 1
        );
        LzExecutorConfig memory exec = abi.decode(raw, (LzExecutorConfig));
        require(exec.maxMessageSize == lane.sendExecutor.maxMessageSize, "LZLaneTesting/send-executor-max-msg-size-mismatch");
        require(exec.executor       == lane.sendExecutor.executor,       "LZLaneTesting/send-executor-mismatch");
    }

    function assertSendUln(LzLaneConfig memory lane) internal view {
        _assertUlnConfig(
            lane.localChain.endpoint, lane.localOApp, lane.localChain.sendLib302, lane.remoteChain.eid,
            lane.sendUln, "send"
        );
    }

    function assertReceiveUln(LzLaneConfig memory lane) internal view {
        if (lane.localChain.recvLib302 == address(0)) return;
        _assertUlnConfig(
            lane.localChain.endpoint, lane.localOApp, lane.localChain.recvLib302, lane.remoteChain.eid,
            lane.recvUln, "recv"
        );
    }

    function assertEnforcedOptions(LzLaneConfig memory lane) internal view {
        uint16 SEND_MSG_TYPE = 1;
        uint16 SEND_CALL_MSG_TYPE = 2;

        if (lane.enforcedOptions.length == 0) return;
        ILZOFTAdapter oft = ILZOFTAdapter(lane.localOApp);
        bytes32 expected = keccak256(lane.enforcedOptions);
        require(keccak256(oft.enforcedOptions(lane.remoteChain.eid, SEND_MSG_TYPE)) == expected, "LZLaneTesting/enforced-options-send-mismatch");
        require(keccak256(oft.enforcedOptions(lane.remoteChain.eid, SEND_CALL_MSG_TYPE)) == expected, "LZLaneTesting/enforced-options-send-and-call-mismatch");
    }

    /// @notice Verify OFT adapter sanity: fees, rate limit accounting type, and paused state.
    /// @dev    Mirrors https://github.com/sky-ecosystem/wh-lz-migration/blob/2c16517aab011ba32ed6f1b5977b888d2a6a753f/deploy/MigrationInit.sol#L142-L151
    function assertOftSanity(address oapp, uint32 remoteEid, uint8 expectedRlAccountingType) internal view {
        ILZOFTAdapter oft = ILZOFTAdapter(oapp);
        require(oft.defaultFeeBps() == 0, "LZLaneTesting/default-fee-bps-nonzero");
        (uint16 feeBps, bool enabled) = oft.feeBps(remoteEid);
        require(feeBps == 0 && !enabled, "LZLaneTesting/fee-bps-nonzero-or-enabled");
        require(!oft.paused(), "LZLaneTesting/paused");
        require(oft.rateLimitAccountingType() == expectedRlAccountingType, "LZLaneTesting/rl-accounting-type-mismatch");
    }

    // --- Encoding helpers ---

    // --- OptionsBuilder constants ---
    // Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L22
    uint16 internal constant TYPE_3      = 3;
    // Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L10
    uint8  internal constant WORKER_ID   = 1;
    // Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L12
    uint8  internal constant OPTION_TYPE = 1;

    /// @notice Encode enforced options for lzReceive (value = 0), replicating OptionsBuilder.addExecutorLzReceiveOption
    /// @dev    See https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L53
    function executorLzReceiveOption(uint128 _gas) internal pure returns (bytes memory) {
        uint16 option_length = 17; // option_length = 1 (optionType) + 16 (uint128 gas) = 17
        return abi.encodePacked(TYPE_3, WORKER_ID, option_length, OPTION_TYPE, _gas);
    }

    /// @notice Encode enforced options for lzReceive (with value), replicating OptionsBuilder.addExecutorLzReceiveOption
    /// @dev    See https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L53
    function executorLzReceiveOption(uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
        uint16 option_length = 33; // option_length = 1 (optionType) + 16 (uint128 gas) + 16 (uint128 value) = 33
        return abi.encodePacked(TYPE_3, WORKER_ID, option_length, OPTION_TYPE, _gas, _value);
    }

    // --- OFT send ceremony ---

    /// @notice Execute an OFT send: build params, quote, record logs, send, return logs.
    function sendOft(
        SkyOFTAdapterLike oft,
        uint32 dstEid,
        address recipient,
        uint256 amount,
        address refundAddress
    ) internal returns (Vm.Log[] memory logs) {
        SkyOFTAdapterLike.SendParam memory sendParams = SkyOFTAdapterLike.SendParam({
            dstEid:       dstEid,
            to:           toBytes32(recipient),
            amountLD:     amount,
            minAmountLD:  amount,
            extraOptions: bytes(""),
            composeMsg:   bytes(""),
            oftCmd:       bytes("")
        });
        SkyOFTAdapterLike.MessagingFee memory msgFee = oft.quoteSend(sendParams, false);
        vm.recordLogs();
        oft.send{value: msgFee.nativeFee}(sendParams, msgFee, payable(refundAddress));
        logs = vm.getRecordedLogs();
    }

    // --- Fork-aware relay ---

    /// @notice Relay LZ messages to the destination fork, then restore the caller's active fork.
    function relayToFork(
        Vm.Log[] memory logs,
        LzLaneConfig memory lane,
        uint256 destForkId
    ) internal {
        uint256 callerForkId = vm.activeFork();
        LZBridgeTesting.relayMessages(
            logs,
            destForkId,
            lane.localChain.endpoint,
            lane.remoteChain.endpoint,
            lane.remoteChain.recvLib302,
            lane.localOApp,
            lane.remoteOApp
        );
        vm.selectFork(callerForkId);
    }

    // --- Lane reversal ---

    /// @notice Create a reverse lane (remote→local) with new DVN configs and enforced options.
    function reverse(
        LzLaneConfig memory lane,
        LzUlnConfig memory sendUln,
        LzUlnConfig memory recvUln,
        bytes memory enforcedOpts
    ) internal pure returns (LzLaneConfig memory rev) {
        rev.localChain    = lane.remoteChain;
        rev.remoteChain   = lane.localChain;
        rev.localOApp     = lane.remoteOApp;
        rev.remoteOApp    = lane.localOApp;
        rev.remotePeer    = toBytes32(lane.localOApp);
        rev.sendExecutor  = lane.recvExecutor;
        rev.recvExecutor  = lane.sendExecutor;
        rev.sendUln       = sendUln;
        rev.recvUln       = recvUln;
        rev.enforcedOptions = enforcedOpts;
    }

    // --- Private helpers ---

    function _assertUlnConfig(
        address endpoint,
        address oapp,
        address lib,
        uint32 eid,
        LzUlnConfig memory expected,
        string memory direction
    ) private view {
        uint32 configType = 2; // Source: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17

        bytes memory raw = ILZEndpointView(endpoint).getConfig(oapp, lib, eid, configType);
        LzUlnConfig memory actual = abi.decode(raw, (LzUlnConfig));
        require(actual.confirmations        == expected.confirmations,        _err(direction, "confirmations-mismatch"));
        require(actual.requiredDVNCount     == expected.requiredDVNCount,     _err(direction, "required-dvn-count-mismatch"));
        require(actual.optionalDVNCount     == expected.optionalDVNCount,     _err(direction, "optional-dvn-count-mismatch"));
        require(actual.optionalDVNThreshold == expected.optionalDVNThreshold, _err(direction, "optional-dvn-threshold-mismatch"));
        require(actual.requiredDVNs.length  == expected.requiredDVNs.length,  _err(direction, "required-dvns-length-mismatch"));
        for (uint256 i = 0; i < expected.requiredDVNs.length; i++) {
            require(actual.requiredDVNs[i] == expected.requiredDVNs[i], _err(direction, "required-dvn-mismatch"));
        }
        require(actual.optionalDVNs.length == expected.optionalDVNs.length, _err(direction, "optional-dvns-length-mismatch"));
        for (uint256 i = 0; i < expected.optionalDVNs.length; i++) {
            require(actual.optionalDVNs[i] == expected.optionalDVNs[i], _err(direction, "optional-dvn-mismatch"));
        }
    }

    function _err(string memory direction, string memory message) private pure returns (string memory) {
        return string.concat("LZLaneTesting/", direction, "-", message);
    }
}
