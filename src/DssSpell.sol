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

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-01-15 MakerDAO Executive Spell | Hash: TODO";

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

    function actions() public override {
        // ---------- Reduce USDS>SKY Emissions ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-12/27606
        // Poll: https://vote.sky.money/polling/QmYmaVVc#poll-detail

        // Yank MCD_VEST_SKY_TREASURY stream ID 9

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY

        // ---------- Reduce LSSKY>SPK Emissions ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-12/27606
        // Poll: https://vote.sky.money/polling/QmYmaVVc#poll-detail

        // Yank MCD_VEST_SPK_TREASURY stream ID 2

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_LSSKY_SPK

        // ---------- Offboard GUNI Vaults ----------
        // Forum: https://forum.sky.money/t/guni-offboarding/27420
        // Forum: https://forum.sky.money/t/guni-offboarding/27420/4

        // Update GUNIV3DAIUSDC1-A Parameters as follows:

        // Liquidation Ratio (mat): increase by 898 percentage points, from 102% to 1000%

        // Liquidation Penalty (chop): reduce by 13 percentage points, from 13% to 0%

        // Flat Kick Incentive (tip): reduce by 300, from 300 to 0

        // Proportional Kick Incentive (chip): reduce by 0.1 percentage points, from 0.1% to 0%

        // Auction Price Multiplier (buf): reduce by 3 percentage points, from 105% to 102%

        // Max Auction Drawdown (cusp): increase by 5 percentage points, from 90% to 95%

        // Auction Price Function (step): reduce by 60 seconds, from 120 seconds to 60 seconds

        // Max Auction Duration (tail): reduce by 9,900 seconds, from 13,200 seconds to 3,300 seconds

        // Update the value of stopped to 0 on MCD_CLIP_GUNIV3DAIUSDC1_A

        // Update GUNIV3DAIUSDC2-A Parameters as follows:

        // Liquidation Ratio (mat): increase by 898 percentage points, from 102% to 1000%

        // Liquidation Penalty (chop): reduce by 13 percentage points, from 13% to 0%

        // Flat Kick Incentive (tip): reduce by 300, from 300 to 0

        // Proportional Kick Incentive (chip): reduce by 0.1 percentage points, from 0.1% to 0%

        // Auction Price Multiplier (buf): reduce by 3 percentage points, from 105% to 102%

        // Max Auction Drawdown (cusp): increase by 5 percentage points, from 90% to 95%

        // Auction Price Function (step): reduce by 60 seconds, from 120 seconds to 60 seconds

        // Max Auction Duration (tail): reduce by 9,900 seconds, from 13,200 seconds to 3,300 seconds

        // Update the value of stopped to 0 on MCD_CLIP_GUNIV3DAIUSDC2_A

        // ---------- Whitelist Keel SubProxy to send cross-chain messages to Solana ----------
        // Forum: https://forum.sky.money/t/executive-inclusion-whitelisting-the-keel-subproxy-to-send-cross-chain-messages-to-solana/27447
        // Atlas: https://sky-atlas.io/#A.6.1.1.3.2.6.1.2.1.1.4.3

        // Allowlist Keel SubProxy for SVM Controller program at ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd

        // Allowlist Keel SubProxy for BPF Loader V3 at BPFLoaderUpgradeab1e11111111111111111111111

        // ---------- Adjust DC-IAM Parameters for Grove ----------
        // Forum: https://forum.sky.money/t/jan-15-2026-parameter-changes-grove-allocator-vault/27595
        // Atlas: https://vote.sky.money/polling/QmYmaVVc#poll-detail

        // Increase ALLOCATOR-BLOOM-A DC-IAM `gap` by 200 million USDS, from 50 million USDS to 250 million USDS

        // Increase ALLOCATOR-BLOOM-A DC-IAM `line `by 2.5 billion USDS, from 2.5 billion USDS to 5 billion USDS

        // ---------- Delegate Compensation for December ----------
        // Forum: https://forum.sky.money/t/december-2025-ranked-delegate-compensation/27605
        // Atlas: https://sky-atlas.io/#A.1.5

        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0

        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3

        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // Transfer 3,723 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307

        // Transfer 1,032 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15-2026-proposed-changes-to-spark-for-upcoming-spell/27585
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xdd79e0fc0308fd0e4393b88cccb8e9b23237c9c398e0458c8c5c43198669e4bb
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x85f242a3d35252380a21ae3e5c80b023122e74af95698a301b541c7b610ffee8
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x994d54ecdadc8f4a69de921207afe3731f3066f086e63ff6a1fd0d4bbfb51b53
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x7eb3a86a4da21475e760e2b2ed0d82fd72bbd4d33c99a0fbedf3d978e472f362

        // Whitelist the Spark Proxy Spell deployed to 0xCE352d9429A5e10b29D3d610C7217f9333e04aB4 with codehash 0x10d1055c82acd9d6804cfb64a80decf3880a257b8af6adad603334325d2586ed; direct execution: no in Spark Starguard

        // ---------- Whitelist Grove Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15th-2026-proposed-changes-to-grove-for-upcoming-spell/27570

        // Whitelist the Grove Proxy Spell deployed to 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748 with codehash 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb; direct execution: no in Grove Starguard 

        // ---------- Whitelist Keel Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/january-15-2026-prime-technical-scope-parameter-change-for-upcoming-spell/27567
        // Poll: https://vote.sky.money/polling/QmdomJ7o

        // Whitelist the Keel Proxy Spell deployed to 0x10AF705fB80bc115FCa83a6B976576Feb1E1aaca with codehash 0xa231c2a3fa83669201d02335e50f6aa379a6319c5972cc046b588c08d91fd44d; direct execution: no in Keel Starguard 
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
