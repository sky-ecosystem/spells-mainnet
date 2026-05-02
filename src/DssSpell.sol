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

import "dss-exec-lib/DssExec.sol";
import "dss-exec-lib/DssAction.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

struct RateLimitConfig {
    uint32 eid;
    uint48 window;
    uint256 limit;
}

struct TxParams {
    uint32 dstEid;
    bytes32 dstTarget;
    bytes dstCallData;
    bytes extraOptions;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

interface SkyOFTAdapterLike {
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigsInbound, RateLimitConfig[] calldata _rateLimitConfigsOutbound) external;
    function unpause() external;
}

interface GovernanceOAppSenderLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
    function quoteTx(TxParams calldata txParams, bool payInLzToken) external view returns (MessagingFee memory);
}

interface L1GovernanceRelayLike {
    function relayRaw(TxParams calldata txParams, MessagingFee calldata fee, address refundAddress) external payable;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-05-07 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Rates ----------
    // Many of the settings that change weekly rely on the rate accumulator
    // described at https://docs.makerdao.com/smart-contract-modules/rates-module
    // To check this yourself, use the following rate calculation (example 8%):
    //
    // $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'
    //
    // A table of rates can be found at
    //    https://ipfs.io/ipfs/QmVp4mhhbwWGTfbh2BzwQB9eiBrQBKiqcPRZCaAxNUaar6
    //
    // uint256 internal constant X_PCT_RATE = ;

    // ---------- Math ----------
    uint256 internal constant WAD = 10 ** 18;

    // ---------- Contracts ----------
    address internal immutable USDS_OFT      = DssExecLib.getChangelogAddress("USDS_OFT");
    address internal immutable LZ_GOV_SENDER = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable LZ_GOV_RELAY  = DssExecLib.getChangelogAddress("LZ_GOV_RELAY");

    // ---------- LayerZero Solana Bridge ----------
    // Solana Mainnet EID.
    uint32  internal constant SOLANA_EID = 30168;
    uint256 internal constant MAX_LZ_GOV_BRIDGE_NATIVE_FEE = 0.01 ether;

    // Solana OFT program ID SKYTAiJRkgexqQqFoqhXdCANyfziwrVrzjhBaCzdbKW encoded as bytes32.
    bytes32 internal constant SOLANA_OFT_PROGRAM = 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649;

    // LayerZero Type 3 options:
    // optionsType: 3, workerId: 1 (Executor), optionSize: 33, optionType: 1 (LZRECEIVE),
    // gas: 4_000_000, value: 4_000_000.
    bytes internal constant LZ_GOV_BRIDGE_EXTRA_OPTIONS =
        hex"000301002101000000000000000000000000003d0900000000000000000000000000003d0900";

    bytes internal constant UNPAUSE_SOLANA_OFT_DST_CALL_DATA =
        hex"00026370695f617574686f726974790000000000000000000000000000000000000001009825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d12200013f209a0238674f2d00";

    bytes internal constant SET_SOLANA_INBOUND_RATE_LIMIT_DST_CALL_DATA =
        hex"00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000040101220873030000000001005039278c0400000100";

    bytes internal constant SET_SOLANA_OUTBOUND_RATE_LIMIT_DST_CALL_DATA =
        hex"00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000030101220873030000000001005039278c0400000100";

    function actions() public override {

        // ---------- Unpause Solana SkyLink Bridge ----------
        // Forum: TODO
        // Atlas: TODO

        // Note: comments in the RateLimitConfig definitions are next to the setRateLimits call.
        RateLimitConfig[] memory inboundRateLimits = new RateLimitConfig[](1);
        inboundRateLimits[0] = RateLimitConfig({
            eid: SOLANA_EID,
            window: 1 days,
            limit: 5_000_000 * WAD
        });

        RateLimitConfig[] memory outboundRateLimits = new RateLimitConfig[](1);
        outboundRateLimits[0] = RateLimitConfig({
            eid: SOLANA_EID,
            window: 1 days,
            limit: 5_000_000 * WAD
        });

        // Set Ethereum USDS OFT rate limits for Solana
        // Call USDS_OFT.setRateLimits with:
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        // RateLimitConfig[] _rateLimitConfigsInbound being an array with one item:
        // uint32 eid being 30168 (Solana Mainnet Eid)
        // uint48 window being 86,400 (1 day)
        // uint256 limit being 5_000_000 * WAD (5,000,000 USDS)
        // RateLimitConfig[] _rateLimitConfigsOutbound being an array with one item:
        // uint32 eid being 30168 (Solana Mainnet Eid)
        // uint48 window being 86,400 (1 day)
        // uint256 limit being 5_000_000 * WAD (5,000,000 USDS)
        SkyOFTAdapterLike(USDS_OFT).setRateLimits(inboundRateLimits, outboundRateLimits);

        // Unpause Ethereum USDS OFT
        // Call USDS_OFT.unpause with:
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        SkyOFTAdapterLike(USDS_OFT).unpause();

        // Allow LZ_GOV_RELAY to send Solana governance payloads
        // Call LZ_GOV_SENDER.setCanCallTarget with:
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // address _srcSender being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // uint32 _dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 _dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID SKYTAiJRkgexqQqFoqhXdCANyfziwrVrzjhBaCzdbKW encoded as bytes32
        // bool _canCall being true
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(LZ_GOV_RELAY, SOLANA_EID, SOLANA_OFT_PROGRAM, true);

        // Note: comments in the TxParams and MessagingFee definitions are next to the relayRaw calls.
        TxParams memory unpauseParams = TxParams({
            dstEid: SOLANA_EID,
            dstTarget: SOLANA_OFT_PROGRAM,
            dstCallData: UNPAUSE_SOLANA_OFT_DST_CALL_DATA,
            extraOptions: LZ_GOV_BRIDGE_EXTRA_OPTIONS
        });

        TxParams memory inboundRateLimitParams = TxParams({
            dstEid: SOLANA_EID,
            dstTarget: SOLANA_OFT_PROGRAM,
            dstCallData: SET_SOLANA_INBOUND_RATE_LIMIT_DST_CALL_DATA,
            extraOptions: LZ_GOV_BRIDGE_EXTRA_OPTIONS
        });

        TxParams memory outboundRateLimitParams = TxParams({
            dstEid: SOLANA_EID,
            dstTarget: SOLANA_OFT_PROGRAM,
            dstCallData: SET_SOLANA_OUTBOUND_RATE_LIMIT_DST_CALL_DATA,
            extraOptions: LZ_GOV_BRIDGE_EXTRA_OPTIONS
        });

        // Note: required to calculate the total native fee for the relayRaw calls.
        MessagingFee memory unpauseFee = GovernanceOAppSenderLike(LZ_GOV_SENDER).quoteTx(unpauseParams, false);
        require(unpauseFee.lzTokenFee == 0, "unpause-lz-token-fee");

        MessagingFee memory inboundRateLimitFee = GovernanceOAppSenderLike(LZ_GOV_SENDER).quoteTx(inboundRateLimitParams, false);
        require(inboundRateLimitFee.lzTokenFee == 0, "inbound-lz-token-fee");

        MessagingFee memory outboundRateLimitFee = GovernanceOAppSenderLike(LZ_GOV_SENDER).quoteTx(outboundRateLimitParams, false);
        require(outboundRateLimitFee.lzTokenFee == 0, "outbound-lz-token-fee");

        uint256 totalNativeFee = unpauseFee.nativeFee + inboundRateLimitFee.nativeFee + outboundRateLimitFee.nativeFee;

        // Note: enforce that the execution upper bound for the relayRaw call is not exceeded.
        require(totalNativeFee <= MAX_LZ_GOV_BRIDGE_NATIVE_FEE, "lz-gov-bridge-fee-too-high");
        // Note: enforce that LZ_GOV_RELAY has enough ETH to pay for the relayRaw call.
        require(LZ_GOV_RELAY.balance >= totalNativeFee, "lz-gov-relay-insufficient-eth");

        // Unpause Solana Sky OFT
        // Call LZ_GOV_RELAY.relayRaw with:
        // LZ_GOV_RELAY being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 from chainlog
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // TxParams txParams:
        // uint32 dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID encoded as bytes32)
        // bytes dstCallData being:
        // 0x00026370695f617574686f726974790000000000000000000000000000000000000001009825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d12200013f209a0238674f2d00
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301002101000000000000000000000000003d0900000000000000000000000000003d0900:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 33
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 4_000_000
        // uint128 _value being 4_000_000
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(unpauseParams, unpauseFee, LZ_GOV_RELAY);

        // Set Solana inbound rate limit for Ethereum -> Solana
        // Call LZ_GOV_RELAY.relayRaw with:
        // LZ_GOV_RELAY being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 from chainlog
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // TxParams txParams:
        // uint32 dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID encoded as bytes32)
        // bytes dstCallData being:
        // 0x00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000040101220873030000000001005039278c0400000100
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301002101000000000000000000000000003d0900000000000000000000000000003d0900:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 33
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 4_000_000
        // uint128 _value being 4_000_000
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(inboundRateLimitParams, inboundRateLimitFee, LZ_GOV_RELAY);

        // Set Solana outbound rate limit for Solana -> Ethereum
        // Call LZ_GOV_RELAY.relayRaw with:
        // LZ_GOV_RELAY being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 from chainlog
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // TxParams txParams:
        // uint32 dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID encoded as bytes32)
        // bytes dstCallData being:
        // 0x00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000030101220873030000000001005039278c0400000100
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301002101000000000000000000000000003d0900000000000000000000000000003d0900:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 33
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 4_000_000
        // uint128 _value being 4_000_000
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(outboundRateLimitParams, outboundRateLimitFee, LZ_GOV_RELAY);

        // ---------- Additional Executive Sheet Actions ----------
        // TODO
    }

}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
