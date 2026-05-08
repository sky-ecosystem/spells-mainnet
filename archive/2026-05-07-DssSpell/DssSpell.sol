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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
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

interface SkyOFTAdapterLike {
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigsInbound, RateLimitConfig[] calldata _rateLimitConfigsOutbound) external;
    function unpause() external;
}

interface GovernanceOAppSenderLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
    function quoteTx(TxParams calldata _params, bool _payInLzToken) external view returns (MessagingFee memory fee);
}

interface L1GovernanceRelayLike {
    function relayRaw(TxParams calldata txParams, MessagingFee calldata fee, address refundAddress) external payable;
}

interface PauseLike {
    function setDelay(uint256) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/aae1a8707278ec69c89ae6ae2848965c73b2fc7a/2026/executive-vote-2026-05-07-solana-bridge-unpause-gsm-increase-msc-staking-rewards-update.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-05-07 MakerDAO Executive Spell | Hash: 0xfc4e7f185a03264f819bfd648aafeb942dd30e1567678b03176e047c9d1a7f63";

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
    uint256 internal constant RAY = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable USDS_OFT                = DssExecLib.getChangelogAddress("USDS_OFT");
    address internal immutable LZ_GOV_SENDER           = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable LZ_GOV_RELAY            = DssExecLib.getChangelogAddress("LZ_GOV_RELAY");
    address internal immutable MCD_PAUSE               = DssExecLib.getChangelogAddress("MCD_PAUSE");
    address internal immutable MCD_VAT                 = DssExecLib.vat();
    address internal immutable MCD_VOW                 = DssExecLib.vow();
    address internal immutable MCD_JUG                 = DssExecLib.jug();
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable SPARK_SUBPROXY          = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable GROVE_SUBPROXY          = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY           = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable OBEX_SUBPROXY           = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY        = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable REWARDS_DIST_LSSKY_SKY  = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable SPARK_STARGUARD         = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD         = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- LayerZero Bridge ----------
    uint32  internal constant SOLANA_EID = 30168;
    uint32  internal constant AVALANCHE_EID = 30106;
    uint256 internal constant MAX_LZ_GOV_BRIDGE_NATIVE_FEE = 0.01 ether;

    // Note: Solana OFT program ID SKYTAiJRkgexqQqFoqhXdCANyfziwrVrzjhBaCzdbKW encoded as bytes32.
    bytes32 internal constant SOLANA_OFT_PROGRAM = 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649;

    // Note: LayerZero Type 3 options:
    //  - optionsType: 3, workerId: 1 (Executor), optionSize: 17 (optionType + gas), optionType: 1 (LZRECEIVE),
    //  - gas: 600_000. value is omitted by the zero-value encoding.
    bytes internal constant LZ_GOV_BRIDGE_EXTRA_OPTIONS =
        hex"000301001101000000000000000000000000000927c0";

    bytes internal constant UNPAUSE_SOLANA_OFT_DST_CALL_DATA =
        hex"00026370695f617574686f726974790000000000000000000000000000000000000001009825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d12200013f209a0238674f2d00";

    bytes internal constant SET_SOLANA_INBOUND_RATE_LIMIT_DST_CALL_DATA =
        hex"00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000040101220873030000000001005039278c0400000100";

    bytes internal constant SET_SOLANA_OUTBOUND_RATE_LIMIT_DST_CALL_DATA =
        hex"00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000030101220873030000000001005039278c0400000100";

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0x84c5E704F7918812BA878ea7Ddbb1365876697C2;
    bytes32 internal constant SPARK_SPELL_HASH = 0x8731ee32dbe70020716a1d7d6623881f52ed120f60bd4876ef39c5e25706f515;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0x8EF80aBDa108a23eA01C8A3D1F5C8B49DD2008e8;
    bytes32 internal constant GROVE_SPELL_HASH = 0x9e8672cc4807d1acac2c63390b2afad3248c109aa4252f4dc5e81a0c95624de7;

    function actions() public override {

        // ---------- Unpause Solana SkyLink Bridge ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-unpausing-the-layerzero-solana-bridge/27894

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
        // (Solana OFT program ID SKYTAiJRkgexqQqFoqhXdCANyfziwrVrzjhBaCzdbKW encoded as bytes32)
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

        // Set the max execution budget for bridging the Solana payloads to 0.01 ETH
        require(totalNativeFee <= MAX_LZ_GOV_BRIDGE_NATIVE_FEE, "lz-gov-bridge-fee-too-high");

        // Note: enforce that LZ_GOV_RELAY has enough ETH to pay for the relayRaw call.
        require(LZ_GOV_RELAY.balance >= totalNativeFee, "lz-gov-relay-insufficient-eth");

        // Set Solana inbound rate limit for Ethereum -> Solana
        // Intended parameters:
        // refill per second: 57_870_370
        // capacity: 5_000_000_000_000
        // rate_limiter_type: net
        // Call LZ_GOV_RELAY.relayRaw with:
        // LZ_GOV_RELAY being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 from chainlog
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // TxParams txParams:
        // uint32 dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID encoded as bytes32)
        // bytes dstCallData being:
        // 0x00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000040101220873030000000001005039278c0400000100
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301001101000000000000000000000000000927c0:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 17 (1 byte for optionType + 16 bytes for _gas; _value is omitted by the zero-value encoding)
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 600_000
        // uint128 _value being 0
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(inboundRateLimitParams, inboundRateLimitFee, LZ_GOV_RELAY);

        // Set Solana outbound rate limit for Solana -> Ethereum
        // Intended parameters:
        // refill per second: 57_870_370
        // capacity: 5_000_000_000_000
        // rate_limiter_type: net
        // Call LZ_GOV_RELAY.relayRaw with:
        // LZ_GOV_RELAY being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 from chainlog
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        // TxParams txParams:
        // uint32 dstEid being 30168 (Solana Mainnet Eid)
        // bytes32 dstTarget being 0x067c7c6c60ba7f1aec14059100df74d6da07e7d31da5dd756c6308f02e661649
        // (Solana OFT program ID encoded as bytes32)
        // bytes dstCallData being:
        // 0x00046370695f617574686f72697479000000000000000000000000000000000000000101b15b6cea974229517bec70478d3f574b4010444df812d75f6ca722fc0fa3256800019825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d1220000000000000000000000000000000000000000000000000000000000000000000000004fbba8398b8c5d2f95750000030101220873030000000001005039278c0400000100
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301001101000000000000000000000000000927c0:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 17 (1 byte for optionType + 16 bytes for _gas; _value is omitted by the zero-value encoding)
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 600_000
        // uint128 _value being 0
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(outboundRateLimitParams, outboundRateLimitFee, LZ_GOV_RELAY);

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
        // bytes extraOptions being LayerZero Type 3 options encoded via abi.encodePacked as 0x000301001101000000000000000000000000000927c0:
        // uint16 optionsType being 3
        // uint8 workerId being 1 (Executor)
        // uint16 optionSize being 17 (1 byte for optionType + 16 bytes for _gas; _value is omitted by the zero-value encoding)
        // uint8 optionType being 1 (LZRECEIVE)
        // uint128 _gas being 600_000
        // uint128 _value being 0
        // MessagingFee fee being the result of LZ_GOV_SENDER.quoteTx(txParams, false)
        // address refundAddress being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
        // msg.value being 0, with LZ_GOV_RELAY paying fee.nativeFee from its pre-funded ETH balance
        L1GovernanceRelayLike(LZ_GOV_RELAY).relayRaw(unpauseParams, unpauseFee, LZ_GOV_RELAY);

        // Note: comments in the RateLimitConfig definitions are next to the setRateLimits call.
        RateLimitConfig[] memory avalancheInboundRateLimits = new RateLimitConfig[](0);

        RateLimitConfig[] memory avalancheOutboundRateLimits = new RateLimitConfig[](1);
        avalancheOutboundRateLimits[0] = RateLimitConfig({
            eid: AVALANCHE_EID,
            window: 1 days,
            limit: 0
        });

        // Disable Ethereum -> Avalanche USDS flow
        // Call USDS_OFT.setRateLimits with:
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        // RateLimitConfig[] _rateLimitConfigsInbound being an empty array
        // RateLimitConfig[] _rateLimitConfigsOutbound being an array with one item:
        // uint32 eid being 30106 (Avalanche Mainnet Eid)
        // uint48 window being 86,400 (1 day)
        // uint256 limit being 0
        SkyOFTAdapterLike(USDS_OFT).setRateLimits(avalancheInboundRateLimits, avalancheOutboundRateLimits);

        // ---------- Increase GSM Pause Delay ----------
        // Forum: https://forum.skyeco.com/t/atlas-edit-weekly-cycle-proposal-week-of-2026-04-27/27864
        // Poll: https://vote.sky.money/polling/QmToMBbA

        // Increase GSM Pause Delay by 24 hours from 24 hours to 48 hours
        PauseLike(MCD_PAUSE).setDelay(48 hours);

        // ---------- Monthly Settlement Cycle for April 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-8-settlement-summary-april-2026/27888
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 9,179,021 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 9_179_021 * WAD);

        // Send 1,512,762 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 1_512_762 * WAD);

        // Mint 9,385,986 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 9_385_986 * WAD);

        // Send 241,690 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 241_690 * WAD);

        // Send 52,915 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 52_915 * WAD);

        // Mint 1,969,499 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_969_499 * WAD);

        // Send 64,862 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 64_862 * WAD);

        // Send 201,469 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 201_469 * WAD);

        // Transfer 3,144,308 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_144_308 * WAD);

        // ---------- Staking Rewards Update ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/19
        // Atlas: https://sky-atlas.io/#a98a1bfe-5713-43f5-a8bd-83c5808900b8

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 239,982,804 SKY
            vestTot: 239_982_804 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/may-7-2026-proposed-changes-to-spark-for-upcoming-spell/27870
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Atlas: https://sky-atlas.io/#6a4870fa-73f1-4d49-b7ee-d531fb59a971
        // Atlas: https://sky-atlas.io/#b69158da-476a-4d4b-b7ef-2f8b96b73d23
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x710eb6996204b3df1eedd19d2f8bea9d0d69cdfa85a31c514527d9c212686348
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x7909f554a2f33155e234788382927f9af0d4dd5a4808349bc0ff57c2ab8b5ce0
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xa72495fc832baced4d2285928e2ca6ff906d7ff88c4dceaaa2d8c4aa6bdfdbdc

        // Whitelist Spark spell with address 0x84c5E704F7918812BA878ea7Ddbb1365876697C2 and codehash 0x8731ee32dbe70020716a1d7d6623881f52ed120f60bd4876ef39c5e25706f515 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/may-7-2026-proposed-changes-to-grove-for-upcoming-spell/27858
        // Poll: https://vote.sky.money/polling/QmToMBbA

        // Whitelist Grove spell with address 0x8EF80aBDa108a23eA01C8A3D1F5C8B49DD2008e8 and codehash 0x9e8672cc4807d1acac2c63390b2afad3248c109aa4252f4dc5e81a0c95624de7 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

    }

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
    /// @param usr The USDS receiver.
    /// @param wad The USDS amount in wad precision (10 ** 18).
    function _transferUsds(address usr, uint256 wad) internal {
        // Note: Enforce whole units to avoid rounding errors
        require(wad % WAD == 0, "transferUsds/non-integer-wad");
        // Note: DssExecLib currently only supports Dai transfers from the surplus buffer.
        DssExecLib.sendPaymentFromSurplusBuffer(address(this), wad / WAD);
        // Note: Approve DAI_USDS for the amount sent to be able to convert it.
        GemAbstract(DAI).approve(DAI_USDS, wad);
        // Note: Convert Dai to USDS for `usr`.
        DaiUsdsLike(DAI_USDS).daiToUsds(usr, wad);
    }

    /// @notice Wraps the operations required to take a payment from a Prime agent
    /// @dev This function effectively increases the debt of the associated Allocator Vault,
    ///      regardless if there is enough room in its debt ceiling.
    /// @param vault The address of the allocator vault
    /// @param wad The amount in wad precision (10 ** 18)
    function _takeAllocatorPayment(address vault, uint256 wad) internal {
        require(wad > 0, "takeAllocatorPayment/zero-amount");
        bytes32 ilk = AllocatorVaultLike(vault).ilk();
        uint256 rate = JugAbstract(MCD_JUG).drip(ilk);
        require(rate > 0, "takeAllocatorPayment/jug-ilk-not-initialized");
        // Note: divup - rounds up in favor of Core.
        uint256 dart = ((wad * RAY - 1) / rate) + 1;
        require(dart <= uint256(type(int256).max), "takeAllocatorPayment/dart-too-large");
        // Note: Take the amount needed, but keep it in the Vow.
        //       This basically generates both sin[vow] and dai[vow] at the same time.
        VatAbstract(MCD_VAT).suck(MCD_VOW, MCD_VOW, dart * rate);
        // Note: Increase the outstanding debt of the vault, while reducing sin[vow], canceling out the sin generated by vat.suck.
        //       The net effect is that dai[vow] and urn[vault].art increase.
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
