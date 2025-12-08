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
    string public constant override description = "2025-12-11 MakerDAO Executive Spell | Hash: TODO";

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

        // ---------- Core Council Executor Agent 1 Launch and Funding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-core-council-executor-agent-1-launch/27514
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-24/27452
        // Atlas: https://sky-atlas.io/#A.2.9.2.5.2.2

        // Initialize new StarGuard module by calling StarGuardInit.init with:

        // chainlog being DssExecLib.LOG

        // cfg.subProxy being 0x64a2b7CfA832fE83BE6a7C1a67521B350519B9c1

        // cfg.subProxyKey being "CCEA1_SUBPROXY"

        // cfg.starGuard being 0x13D95B35248D04FB60597dd1b27BE13E73Fe0a12

        // cfg.starGuardKey being "CCEA1_STARGUARD"

        // cfg.maxDelay being 7 days

        // Add new StarGuard module to the StarGuardJob

        // StarGuardJobLike(CRON_STARGUARD_JOB).add(CCEA1_STARGUARD)

        // Transfer 20,000,000 USDS to the Core Council Executor Agent 1 SubProxy at 0x64a2b7CfA832fE83BE6a7C1a67521B350519B9c1

        // Transfer 5,000,000 USDS to the Core Council Buffer Multisig at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364

        // ---------- Adjust USDS >> SKY Farm (Pending Forum Post) ----------
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/24
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/25
        // Atlas: https://sky-atlas.io/#A.4.3.2.1

        // VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY

        // MCD_VEST_SKY_TREASURY Vest Stream  | from: 'block.timestamp' | tau: 182 days | tot: 60,297,057 SKY | usr: REWARDS_DIST_USDS_SKY

        // res: 1 (restricted)

        // Adjust the Sky allowance for MCD_VEST_SKY_TREASURY, reducing it by the remaining yanked stream amount and increasing it by the new stream total

        // Yank MCD_VEST_SKY_TREASURY vest with ID 7

        // File the new stream ID on REWARDS_DIST_USDS_SKY

        // ---------- Increase delayed upgrade penalty to 2% ----------
        // Forum: https://forum.sky.money/t/delayed-migration-penalty-update-december-11th-spell/27520
        // Atlas: https://sky-atlas.io/#A.4.1.2.1.1.1.1

        // Increase delayed upgrade penalty by 1 percentage point, from 1% to 2% fee on MKR_SKY

        // ---------- stUSDS capped OSM and Liquidation Ratio adjustments (Pending Atlas Edit Post) ----------

        // ---------- Adjust stUSDS-BEAM Parameters ----------
        // Forum: https://forum.sky.money/t/stusds-beam-rate-setter-configuration/27161/76

        // Increase stepStrBps by 1,000 basis points, from 500 bps to 1,500 bps

        // Increase stepDutyBps by 1,000 basis points, from 500 bps to 1,500 bps

        // ---------- DAO Resolution for HV Bank ----------
        // Resolution: https://gateway.pinata.cloud/ipfs/bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq
        // Forum: https://forum.sky.money/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/29
        // Forum: https://forum.sky.money/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/30

        // Approve DAO Resolution with hash bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq

        // ---------- Delegate Compensation for November ----------
        // Forum: https://forum.sky.money/t/november-2025-ranked-delegate-compensation/27506
        // Atlas: https://sky-atlas.io/#A.1.5

        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0

        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3

        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // Transfer 3,788 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307

        // Transfer 3,027 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C

        // ---------- Atlas Core Development USDS Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-december-2025/27496
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 50,167 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // Transfer 16,417 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // ---------- Atlas Core Development SKY Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-december-2025/27496
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 330,000 SKY to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // Transfer 288,000 SKY to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/december-11-2025-proposed-changes-to-spark-for-upcoming-spell/27481
        // Atlas: https://sky-atlas.io/#A.2.9.2.2.2.5.5.1
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x1fe374e0ba506993768069bb856f91da7d854c9ea6ea9a31cc342267b79993d7
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x121b44858123a32f49d8c203ba419862f633c642ac2739030763433a8e756d61
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x2cb808bb15c7f85e6759467c715bf6bd96b1933109b7540f87dfbbcba0e57914
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x007a555d46f2c215b7d69163e763f03c3b91f31cd43dd08de88a1531631a4766
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x9b21777dfa9f7628060443a046b76a5419740f692557ef45c92f6fac1ff31801

        // Whitelist the Spark Proxy Spell deployed to TBD with codehash TBD; direct execution: no in Spark Starguard

        // ---------- Whitelist Grove Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.8.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.9.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.7.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.10.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.11.1.2

        // Whitelist the Grove Proxy Spell deployed to TBD with codehash TBD; direct execution: no in Grove Starguard
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
