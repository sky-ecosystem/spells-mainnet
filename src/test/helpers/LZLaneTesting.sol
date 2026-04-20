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
    function peers(uint32 eid) external view returns (bytes32);
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
    function defaultFeeBps() external view returns (uint16);
    function enforcedOptions(uint32 eid, uint16 msgType) external view returns (bytes memory);
    function feeBps(uint32 dstEid) external view returns (uint16 feeBps, bool enabled);
    function inboundRateLimits(uint32 dstEid) external view returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
    function outboundRateLimits(uint32 srcEid) external view returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
    function pause() external;
    function paused() external view returns (bool);
    function pausers(address pauser) external view returns (bool canPause);
    function quoteSend(SendParam memory _sendParam, bool _payInLzToken) external view returns (MessagingFee memory msgFee);
    function rateLimitAccountingType() external view returns (uint8);
    function send(SendParam memory _sendParam, MessagingFee memory _fee, address _refundAddress)
        external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigsInbound, RateLimitConfig[] calldata _rateLimitConfigsOutbound) external;
    function token() external view returns (address);
    function unpause() external;
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

struct LzEnforcedOptionsConfig {
    bytes send;
    bytes sendAndCall;
}

struct LzLaneConfig {
    address                 owner;
    uint32                  remoteEid;
    address                 remoteOApp;
    LzExecutorConfig        sendExecutor;
    LzUlnConfig             sendUln;
    LzUlnConfig             recvUln;
    LzEnforcedOptionsConfig enforcedOptions;
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

    function assertOwner(address oapp, LzLaneConfig memory cfg) internal view {
        vm.assertEq(ILZOApp(oapp).owner(), cfg.owner, "LZLaneTesting/owner-mismatch");
    }

    function assertDelegate(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        vm.assertEq(ILZEndpointView(chain.endpoint).delegates(oapp), cfg.owner, "LZLaneTesting/delegate-mismatch");
    }

    function assertPeerSet(address oapp, LzLaneConfig memory cfg) internal view {
        vm.assertEq(ILZOApp(oapp).peers(cfg.remoteEid), toBytes32(cfg.remoteOApp), "LZLaneTesting/peer-mismatch");
    }

    function assertSendLibrary(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        if (chain.sendLib302 == address(0)) return;
        vm.assertEq(ILZEndpointView(chain.endpoint).getSendLibrary(oapp, cfg.remoteEid), chain.sendLib302, "LZLaneTesting/send-library-mismatch");
    }

    function assertReceiveLibrary(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        if (chain.recvLib302 == address(0)) return;
        (address lib,) = ILZEndpointView(chain.endpoint).getReceiveLibrary(oapp, cfg.remoteEid);
        vm.assertEq(lib, chain.recvLib302, "LZLaneTesting/recv-library-mismatch");
    }

    function assertSendExecutor(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        if (chain.sendLib302 == address(0)) return;
        bytes memory raw = ILZEndpointView(chain.endpoint).getConfig(
            oapp, chain.sendLib302, cfg.remoteEid, 1
        );
        LzExecutorConfig memory exec = abi.decode(raw, (LzExecutorConfig));
        vm.assertEq(exec.maxMessageSize, cfg.sendExecutor.maxMessageSize, "LZLaneTesting/send-executor-max-msg-size-mismatch");
        vm.assertEq(exec.executor, cfg.sendExecutor.executor, "LZLaneTesting/send-executor-mismatch");
    }

    function assertSendUln(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        if (chain.sendLib302 == address(0)) return;
        _assertUlnConfig(
            chain.endpoint, oapp, chain.sendLib302, cfg.remoteEid,
            cfg.sendUln, "send"
        );
    }

    function assertReceiveUln(LzChainConfig memory chain, address oapp, LzLaneConfig memory cfg) internal view {
        if (chain.recvLib302 == address(0)) return;
        _assertUlnConfig(
            chain.endpoint, oapp, chain.recvLib302, cfg.remoteEid,
            cfg.recvUln, "recv"
        );
    }

    function assertEnforcedOptions(address oapp, LzLaneConfig memory cfg) internal view {
        uint16 SEND_MSG_TYPE = 1;
        uint16 SEND_CALL_MSG_TYPE = 2;

        SkyOFTAdapterLike oft = SkyOFTAdapterLike(oapp);

        if (cfg.enforcedOptions.send.length > 0) {
            vm.assertEq(
                oft.enforcedOptions(cfg.remoteEid, SEND_MSG_TYPE),
                cfg.enforcedOptions.send,
                "LZLaneTesting/enforced-options-send-mismatch"
            );
        }

        if (cfg.enforcedOptions.sendAndCall.length > 0) {
            vm.assertEq(
                oft.enforcedOptions(cfg.remoteEid, SEND_CALL_MSG_TYPE),
                cfg.enforcedOptions.sendAndCall,
                "LZLaneTesting/enforced-options-send-and-call-mismatch"
            );
        }
    }

    /// @notice Verify OFT adapter sanity: fees, rate limit accounting type, and paused state.
    /// @dev    Mirrors https://github.com/sky-ecosystem/wh-lz-migration/blob/2c16517aab011ba32ed6f1b5977b888d2a6a753f/deploy/MigrationInit.sol#L142-L151
    function assertOftSanity(address oapp, uint32 remoteEid, address expectedToken, uint8 expectedRlAccountingType) internal view {
        SkyOFTAdapterLike oft = SkyOFTAdapterLike(oapp);
        vm.assertEq(oft.token(), expectedToken, "LZLaneTesting/token-mismatch");
        vm.assertEq(oft.defaultFeeBps(), 0, "LZLaneTesting/default-fee-bps-nonzero");
        (uint16 feeBps, bool enabled) = oft.feeBps(remoteEid);
        vm.assertEq(feeBps, 0, "LZLaneTesting/fee-bps-nonzero");
        vm.assertEq(enabled, false, "LZLaneTesting/fee-bps-enabled");
        vm.assertTrue(!oft.paused(), "LZLaneTesting/paused");
        vm.assertEq(oft.rateLimitAccountingType(), expectedRlAccountingType, "LZLaneTesting/rl-accounting-type-mismatch");
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
        uint16 optionLength = 17; // optionLength = 1 (optionType) + 16 (uint128 gas) = 17
        return abi.encodePacked(TYPE_3, WORKER_ID, optionLength, OPTION_TYPE, _gas);
    }

    /// @notice Encode enforced options for lzReceive (with value), replicating OptionsBuilder.addExecutorLzReceiveOption
    /// @dev    See https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L53
    function executorLzReceiveOption(uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
        uint16 optionLength = 33; // optionLength = 1 (optionType) + 16 (uint128 gas) + 16 (uint128 value) = 33
        return abi.encodePacked(TYPE_3, WORKER_ID, optionLength, OPTION_TYPE, _gas, _value);
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
        LzChainConfig memory srcChain,
        LzChainConfig memory dstChain,
        address srcOApp,
        address dstOApp,
        uint256 destForkId
    ) internal {
        uint256 callerForkId = vm.activeFork();
        LZBridgeTesting.relayMessages(
            logs,
            destForkId,
            srcChain.endpoint,
            dstChain.endpoint,
            dstChain.recvLib302,
            srcOApp,
            dstOApp
        );
        vm.selectFork(callerForkId);
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
        vm.assertEq(actual.confirmations, expected.confirmations, _err(direction, "confirmations-mismatch"));
        vm.assertEq(actual.requiredDVNCount, expected.requiredDVNCount, _err(direction, "required-dvn-count-mismatch"));
        vm.assertEq(actual.optionalDVNCount, expected.optionalDVNCount, _err(direction, "optional-dvn-count-mismatch"));
        vm.assertEq(actual.optionalDVNThreshold, expected.optionalDVNThreshold, _err(direction, "optional-dvn-threshold-mismatch"));
        vm.assertEq(actual.requiredDVNs.length, expected.requiredDVNs.length, _err(direction, "required-dvns-length-mismatch"));
        for (uint256 i = 0; i < expected.requiredDVNs.length; i++) {
            vm.assertEq(actual.requiredDVNs[i], expected.requiredDVNs[i], _err(direction, "required-dvn-mismatch"));
        }
        vm.assertEq(actual.optionalDVNs.length, expected.optionalDVNs.length, _err(direction, "optional-dvns-length-mismatch"));
        for (uint256 i = 0; i < expected.optionalDVNs.length; i++) {
            vm.assertEq(actual.optionalDVNs[i], expected.optionalDVNs[i], _err(direction, "optional-dvn-mismatch"));
        }
    }

    function _err(string memory direction, string memory message) private pure returns (string memory) {
        return string.concat("LZLaneTesting/", direction, "-", message);
    }
}
