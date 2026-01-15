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
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { VestAbstract } from "dss-interfaces/dss/VestAbstract.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256 amount);
}

interface GovernanceOAppSenderLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/b8d7190058360e315d762041c135e8080eeadb5e/2026/executive-vote-2026-01-15-reduce-rewards-guni-offboarding.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-01-15 MakerDAO Executive Spell | Hash: 0x3a31416de6e8e8a7abb4948a7da9b60c8c237a8a9ead1fee107f435d325a2a11";

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
    uint256 internal constant MILLION   = 10 ** 6;
    uint256 internal constant WAD       = 10 ** 18;
    uint256 internal constant RAY       = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable DAI                              = DssExecLib.dai();
    address internal immutable MCD_SPOT                         = DssExecLib.spotter();
    address internal immutable SKY                              = DssExecLib.getChangelogAddress("SKY");
    address internal immutable SPK                              = DssExecLib.getChangelogAddress("SPK");
    address internal immutable DAI_USDS                         = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_VEST_SKY_TREASURY            = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable REWARDS_DIST_USDS_SKY            = DssExecLib.getChangelogAddress("REWARDS_DIST_USDS_SKY");
    address internal immutable MCD_VEST_SPK_TREASURY            = DssExecLib.getChangelogAddress("MCD_VEST_SPK_TREASURY");
    address internal immutable REWARDS_DIST_LSSKY_SPK           = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SPK");
    address internal immutable MCD_CLIP_GUNIV3DAIUSDC1_A        = DssExecLib.getChangelogAddress("MCD_CLIP_GUNIV3DAIUSDC1_A");
    address internal immutable MCD_CLIP_CALC_GUNIV3DAIUSDC1_A   = DssExecLib.getChangelogAddress("MCD_CLIP_CALC_GUNIV3DAIUSDC1_A");
    address internal immutable MCD_CLIP_GUNIV3DAIUSDC2_A        = DssExecLib.getChangelogAddress("MCD_CLIP_GUNIV3DAIUSDC2_A");
    address internal immutable MCD_CLIP_CALC_GUNIV3DAIUSDC2_A   = DssExecLib.getChangelogAddress("MCD_CLIP_CALC_GUNIV3DAIUSDC2_A");
    address internal immutable KEEL_SUBPROXY                    = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable LZ_GOV_SENDER                    = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable SPARK_STARGUARD                  = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD                  = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable KEEL_STARGUARD                   = DssExecLib.getChangelogAddress("KEEL_STARGUARD");

    // ---------- LayerZero ----------
    uint32 internal constant SOL_EID = 30168;
    // Note: base58 ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd&output_type=hex
    bytes32 internal constant SVM_CONTROLLER = 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;
    // Note: base58 BPFLoaderUpgradeab1e11111111111111111111111 to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=BPFLoaderUpgradeab1e11111111111111111111111&output_type=hex
    bytes32 internal constant BPF_LOADER = 0x02a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a1004800000;

    // ---------- Wallets ----------
    address internal constant AEGIS_D       = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
    address internal constant BLUE          = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA   = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2      = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant TANGO         = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant SKY_STAKING   = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0xCE352d9429A5e10b29D3d610C7217f9333e04aB4;
    bytes32 internal constant SPARK_SPELL_HASH = 0x10d1055c82acd9d6804cfb64a80decf3880a257b8af6adad603334325d2586ed;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL       = 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748;
    bytes32 internal constant GROVE_SPELL_HASH  = 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb;

    // ---------- Keel Proxy Spell ----------
    address internal constant KEEL_SPELL       = 0x10AF705fB80bc115FCa83a6B976576Feb1E1aaca;
    bytes32 internal constant KEEL_SPELL_HASH  = 0xa231c2a3fa83669201d02335e50f6aa379a6319c5972cc046b588c08d91fd44d;

    function actions() public override {
        // ---------- Reduce USDS>SKY Emissions ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-12/27606
        // Poll: https://vote.sky.money/polling/QmYmaVVc

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY
        VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).distribute();

        {
            // Note: Get the previous allowance
            uint256 pallowance = GemAbstract(SKY).allowance(address(this), MCD_VEST_SKY_TREASURY);
            // Note: Get the remaining allowance for the yanked stream
            uint256 ytot = VestAbstract(MCD_VEST_SKY_TREASURY).tot(9);
            uint256 yrxd = VestAbstract(MCD_VEST_SKY_TREASURY).rxd(9);
            uint256 yallowance = ytot - yrxd;
            // Note: Calculate the new allowance
            uint256 allowance = pallowance - yallowance;
            // Note: Set the allowance
            GemAbstract(SKY).approve(MCD_VEST_SKY_TREASURY, allowance);
        }

        // Yank MCD_VEST_SKY_TREASURY stream ID 9
        VestAbstract(MCD_VEST_SKY_TREASURY).yank(9);

        // ---------- Reduce LSSKY>SPK Emissions ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-12/27606
        // Poll: https://vote.sky.money/polling/QmYmaVVc

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_LSSKY_SPK
        VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).distribute();

        {
            // Note: Get the previous allowance
            uint256 pallowance = GemAbstract(SPK).allowance(address(this), MCD_VEST_SPK_TREASURY);
            // Note: Get the remaining allowance for the yanked stream
            uint256 ytot = VestAbstract(MCD_VEST_SPK_TREASURY).tot(2);
            uint256 yrxd = VestAbstract(MCD_VEST_SPK_TREASURY).rxd(2);
            uint256 yallowance = ytot - yrxd;
            // Note: Calculate the new allowance
            uint256 allowance = pallowance - yallowance;
            // Note: Set the allowance
            GemAbstract(SPK).approve(MCD_VEST_SPK_TREASURY, allowance);
        }

        // Yank MCD_VEST_SPK_TREASURY stream ID 2
        VestAbstract(MCD_VEST_SPK_TREASURY).yank(2);

        // ---------- Offboard GUNI Vaults ----------
        // Forum: https://forum.sky.money/t/guni-offboarding/27420
        // Forum: https://forum.sky.money/t/guni-offboarding/27420/4

        // Update GUNIV3DAIUSDC1-A Parameters as follows:

        // Liquidation Ratio (mat): increase by 898 percentage points, from 102% to 1000%
        // Note: We are using low level methods because DssExecLib only allows setting `mat < 1000%`: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExecLib.sol#L717
        DssExecLib.setValue(MCD_SPOT, "GUNIV3DAIUSDC1-A", "mat", 10 * RAY);

        // Note: Propagate the change to the vat
        DssExecLib.updateCollateralPrice("GUNIV3DAIUSDC1-A");

        // Liquidation Penalty (chop): reduce by 13 percentage points, from 13% to 0%
        DssExecLib.setIlkLiquidationPenalty("GUNIV3DAIUSDC1-A", 0);

        // Flat Kick Incentive (tip): reduce by 300, from 300 to 0
        DssExecLib.setKeeperIncentiveFlatRate("GUNIV3DAIUSDC1-A", 0);

        // Proportional Kick Incentive (chip): reduce by 0.1 percentage points, from 0.1% to 0%
        DssExecLib.setKeeperIncentivePercent("GUNIV3DAIUSDC1-A", 0);

        // Auction Price Multiplier (buf): reduce by 3 percentage points, from 105% to 102%
        DssExecLib.setStartingPriceMultiplicativeFactor("GUNIV3DAIUSDC1-A", 102_00);

        // Max Auction Drawdown (cusp): increase by 5 percentage points, from 90% to 95%
        DssExecLib.setAuctionPermittedDrop("GUNIV3DAIUSDC1-A", 95_00);

        // Auction Price Function (step): reduce by 60 seconds, from 120 seconds to 60 seconds
        DssExecLib.setValue(MCD_CLIP_CALC_GUNIV3DAIUSDC1_A, "step", 60);

        // Max Auction Duration (tail): reduce by 9,900 seconds, from 13,200 seconds to 3,300 seconds
        DssExecLib.setAuctionTimeBeforeReset("GUNIV3DAIUSDC1-A", 3_300);

        // Update the value of stopped to 0 on MCD_CLIP_GUNIV3DAIUSDC1_A
        DssExecLib.setValue(MCD_CLIP_GUNIV3DAIUSDC1_A, "stopped", 0);

        // Update GUNIV3DAIUSDC2-A Parameters as follows:

        // Liquidation Ratio (mat): increase by 898 percentage points, from 102% to 1000%
        // Note: We are using low level methods because DssExecLib only allows setting `mat < 1000%`: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExecLib.sol#L717
        DssExecLib.setValue(MCD_SPOT, "GUNIV3DAIUSDC2-A", "mat", 10 * RAY);

        // Note: Propagate the change to the vat
        DssExecLib.updateCollateralPrice("GUNIV3DAIUSDC2-A");

        // Liquidation Penalty (chop): reduce by 13 percentage points, from 13% to 0%
        DssExecLib.setIlkLiquidationPenalty("GUNIV3DAIUSDC2-A", 0);

        // Flat Kick Incentive (tip): reduce by 300, from 300 to 0
        DssExecLib.setKeeperIncentiveFlatRate("GUNIV3DAIUSDC2-A", 0);

        // Proportional Kick Incentive (chip): reduce by 0.1 percentage points, from 0.1% to 0%
        DssExecLib.setKeeperIncentivePercent("GUNIV3DAIUSDC2-A", 0);

        // Auction Price Multiplier (buf): reduce by 3 percentage points, from 105% to 102%
        DssExecLib.setStartingPriceMultiplicativeFactor("GUNIV3DAIUSDC2-A", 102_00);

        // Max Auction Drawdown (cusp): increase by 5 percentage points, from 90% to 95%
        DssExecLib.setAuctionPermittedDrop("GUNIV3DAIUSDC2-A", 95_00);

        // Auction Price Function (step): reduce by 60 seconds, from 120 seconds to 60 seconds
        DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_GUNIV3DAIUSDC2_A, 60 seconds, 99_90);

        // Max Auction Duration (tail): reduce by 9,900 seconds, from 13,200 seconds to 3,300 seconds
        DssExecLib.setAuctionTimeBeforeReset("GUNIV3DAIUSDC2-A", 3_300);

        // Update the value of stopped to 0 on MCD_CLIP_GUNIV3DAIUSDC2_A
        DssExecLib.setValue(MCD_CLIP_GUNIV3DAIUSDC2_A, "stopped", 0);

        // ---------- Whitelist Keel SubProxy to send cross-chain messages to Solana ----------
        // Forum: https://forum.sky.money/t/executive-inclusion-whitelisting-the-keel-subproxy-to-send-cross-chain-messages-to-solana/27447
        // Atlas: https://sky-atlas.io/#A.6.1.1.3.2.6.1.2.1.1.4.3

        // Allowlist Keel SubProxy for SVM Controller program at ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            KEEL_SUBPROXY,
            SOL_EID,
            SVM_CONTROLLER,
            true
        );

        // Allowlist Keel SubProxy for BPF Loader V3 at BPFLoaderUpgradeab1e11111111111111111111111
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            KEEL_SUBPROXY,
            SOL_EID,
            BPF_LOADER,
            true
        );

        // ---------- Adjust DC-IAM Parameters for Grove ----------
        // Forum: https://forum.sky.money/t/jan-15-2026-parameter-changes-grove-allocator-vault/27595
        // Atlas: https://vote.sky.money/polling/QmYmaVVc

        // Note: use DssExecLib.setIlkAutoLineParameters() to update multiple ALLOCATOR-BLOOM-A DC-IAM parameters at the same time:
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-BLOOM-A",
            // Increase ALLOCATOR-BLOOM-A DC-IAM `gap` by 200 million USDS, from 50 million USDS to 250 million USDS
            _gap: 250 * MILLION,
            // Increase ALLOCATOR-BLOOM-A DC-IAM `line `by 2.5 billion USDS, from 2.5 billion USDS to 5 billion USDS
            _amount: 5000 * MILLION,
            // Note: Keep `ttl` unchanged at 86,400 seconds
            _ttl: 86400 seconds
        });

        // ---------- Delegate Compensation for December ----------
        // Forum: https://forum.sky.money/t/december-2025-ranked-delegate-compensation/27605
        // Atlas: https://sky-atlas.io/#A.1.5

        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        _transferUsds(AEGIS_D, 4_000 * WAD);

        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // Transfer 3,723 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 3_723 * WAD);

        // Transfer 1,032 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        _transferUsds(SKY_STAKING, 1_032 * WAD);

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15-2026-proposed-changes-to-spark-for-upcoming-spell/27585
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xdd79e0fc0308fd0e4393b88cccb8e9b23237c9c398e0458c8c5c43198669e4bb
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x85f242a3d35252380a21ae3e5c80b023122e74af95698a301b541c7b610ffee8
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x994d54ecdadc8f4a69de921207afe3731f3066f086e63ff6a1fd0d4bbfb51b53
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x7eb3a86a4da21475e760e2b2ed0d82fd72bbd4d33c99a0fbedf3d978e472f362

        // Whitelist the Spark Proxy Spell deployed to 0xCE352d9429A5e10b29D3d610C7217f9333e04aB4 with codehash 0x10d1055c82acd9d6804cfb64a80decf3880a257b8af6adad603334325d2586ed; direct execution: no in Spark Starguard
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Whitelist Grove Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15th-2026-proposed-changes-to-grove-for-upcoming-spell/27570
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.2.1.1.1.1.2.3
        // Poll: https://vote.sky.money/polling/QmcJnbbu
        // Poll: https://vote.sky.money/polling/QmWNWJLS

        // Whitelist the Grove Proxy Spell deployed to 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748 with codehash 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb; direct execution: no in Grove Starguard 
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Whitelist Keel Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15-2026-prime-technical-scope-parameter-change-for-upcoming-spell/27567
        // Poll: https://vote.sky.money/polling/QmcJnbbu

        // Whitelist the Keel Proxy Spell deployed to 0x10AF705fB80bc115FCa83a6B976576Feb1E1aaca with codehash 0xa231c2a3fa83669201d02335e50f6aa379a6319c5972cc046b588c08d91fd44d; direct execution: no in Keel Starguard 
        StarGuardLike(KEEL_STARGUARD).plot(KEEL_SPELL, KEEL_SPELL_HASH);
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
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
