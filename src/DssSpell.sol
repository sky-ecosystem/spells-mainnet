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
import {DssExecLib} from "dss-exec-lib/DssExecLib.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import { TreasuryFundedFarmingInit, FarmingInitParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface DssLitePsmLike {
    function kiss(address usr) external;
}

interface SubProxyMethodsLike {
    function transfer(address token, address to, uint256 amount) external;
}

interface SubProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

abstract contract DssAction {

    using DssExecLib for *;

    // Modifier used to limit execution time when office hours is enabled
    modifier limited {
        require(DssExecLib.canCast(uint40(block.timestamp), officeHours()), "Outside office hours");
        _;
    }

    // Office Hours defaults to true by default.
    //   To disable office hours, override this function and
    //    return false in the inherited action.
    function officeHours() public view virtual returns (bool) {
        return true;
    }

    // DssExec calls execute. We limit this function subject to officeHours modifier.
    function execute() external limited {
        actions();
    }

    // DssAction developer must override `actions()` and place all actions to be called inside.
    //   The DssExec function will call this subject to the officeHours limiter
    //   By keeping this function public we allow simulations of `execute()` on the actions outside of the cast time.
    function actions() public virtual;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://<executive-vote-canonical-post> -q -O - 2>/dev/null)"
    function description() external view virtual returns (string memory);

    // Returns the next available cast time
    function nextCastTime(uint256 eta) external virtual view returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
    }
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-07-02 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Set earliest execution date July 6, 18:00 UTC ----------

    // Note: 2026-07-06 18:00:00 UTC
    uint256 internal constant JUL_06_2026_18_00_UTC = 1783360800;

    // Note: Override nextCastTime to inform keepers about the earliest execution time
    function nextCastTime(uint256 eta) external view override returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        // Note: First calculate the standard office hours cast time
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
        // Note: Then ensure it's not before our minimum date
        return castTime < JUL_06_2026_18_00_UTC ? JUL_06_2026_18_00_UTC : castTime;
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

    uint256 internal constant MILLION = 10 ** 6;

    // ---------- Contracts ----------
    address internal immutable USDS                   = DssExecLib.getChangelogAddress("USDS");
    address internal immutable MCD_LITE_PSM_USDC_A    = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable AMATSU_SUBPROXY        = DssExecLib.getChangelogAddress("AMATSU_SUBPROXY");
    address internal immutable SPARK_STARGUARD        = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD        = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable SKYBASE_STARGUARD      = DssExecLib.getChangelogAddress("SKYBASE_STARGUARD");
    address internal immutable CRON_REWARDS_DIST_JOB  = DssExecLib.getChangelogAddress("CRON_REWARDS_DIST_JOB");

    address internal constant GROVE_ALM_PROXY         = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;
    address internal constant PAU_BEACON              = 0x829dC2b7E94B1954F0764E573f2E0d45Afa28199;
    address internal constant SUBPROXY_METHODS        = 0x5162489F4FEa651b76c75193387d08aAAC9CB52C;
    address internal constant MCD_VEST_GROVE_TREASURY = 0xcBCfCD450de686894d3C5E7E8975cF23EEF077B2;
    address internal constant GROVE                   = 0xB30FE1Cf884B48a22a50D22a9282004F2c5E9406;
    address internal constant REWARDS_USDS_GROVE      = 0x4E41488C19cD35EB4de3083Fc3e204854c75c86a;
    address internal constant REWARDS_DIST_USDS_GROVE = 0xAf7a108B4fB0b2F65E1Acc9E1a548abe482559C4;
    
    // ---------- Wallets ----------
    address internal constant SKY_FRONTIER_FOUNDATION = 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0xcc7529473B850103524905D3914470898aDe8747;
    bytes32 internal constant SPARK_SPELL_HASH = 0xf952ba1ea1df8c42217cecd3c4e88abcde2864fbf1e4465b1a13af0bf05e00f0;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0xa21d2E301D50AfF797143deb5a7C400482E9122C;
    bytes32 internal constant GROVE_SPELL_HASH = 0xb3377dba77dfd8bce7c272e7c4c445ab48b3d0ec3fd0a52f512a39974f059a0f;

    // ---------- Skybase Proxy Spell ----------
    address internal constant SKYBASE_SPELL      = 0xd3e4e16ED515Be794fd181D7d2cEB0447A6f2cb5;
    bytes32 internal constant SKYBASE_SPELL_HASH = 0x09c387eed3e4373a4cc91fc28686e103cfc704335279f65f2f7308f474c002d9;

    function actions() public override {
        // ---------- Set earliest execution date July 6, 18:00 UTC ----------
        require(block.timestamp >= JUL_06_2026_18_00_UTC, "Spell can only be cast after July 06, 2026, 18:00 UTC");

        // ---------- Set Up GROVE Token Rewards ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-grove-farm/27999
        // Poll: https://vote.sky.money/polling/Qmd3gCcD

        // Add 0xcBCfCD450de686894d3C5E7E8975cF23EEF077B2 to the chainlog as MCD_VEST_GROVE_TREASURY
        DssExecLib.setChangelogAddress("MCD_VEST_GROVE_TREASURY", MCD_VEST_GROVE_TREASURY);

        // Add 0xB30FE1Cf884B48a22a50D22a9282004F2c5E9406 to the chainlog as GROVE
        DssExecLib.setChangelogAddress("GROVE", GROVE);

        // Initialize USDS -> GROVE farm with TreasuryFundedFarmingInit.initFarm
        TreasuryFundedFarmingInit.initFarm(
            FarmingInitParams({
                // stakingToken: USDS
                stakingToken: USDS,
                // rewardsToken: GROVE
                rewardsToken: GROVE,
                // rewards: 0x4E41488C19cD35EB4de3083Fc3e204854c75c86a
                rewards: REWARDS_USDS_GROVE,
                // rewardsKey: "REWARDS_USDS_GROVE"
                rewardsKey: "REWARDS_USDS_GROVE",
                // dist: 0xAf7a108B4fB0b2F65E1Acc9E1a548abe482559C4
                dist: REWARDS_DIST_USDS_GROVE,
                // distKey: "REWARDS_DIST_USDS_GROVE"
                distKey: "REWARDS_DIST_USDS_GROVE",
                // distJob: CRON_REWARDS_DIST_JOB
                distJob: CRON_REWARDS_DIST_JOB,
                // distJobInterval: 7 days - 1 hours
                distJobInterval: 7 days - 1 hours,
                // vest: MCD_VEST_GROVE_TREASURY
                vest: MCD_VEST_GROVE_TREASURY,
                // vestTot: 2.45 billion GROVE
                vestTot: 2_450_000_000 * WAD,
                // vestBgn: block.timestamp - 7 days
                vestBgn: block.timestamp - 7 days,
                // vestTau: 730 days
                vestTau: 730 days
            })
        );

        // ---------- Whitelist New Grove ALMProxy on LitePSM ----------
        // Forum: https://forum.skyeco.com/t/july-2-2026-proposed-changes-to-grove-for-upcoming-spell/27976
        // Poll: https://vote.sky.money/polling/QmdXjfm6

        // Whitelist Grove ALMProxy at 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153 on MCD_LITE_PSM_USDC_A
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(GROVE_ALM_PROXY);

        // ---------- Add PAU Beacon to the Chainlog ----------
        // Forum: https://forum.skyeco.com/t/diamond-pau-and-beacon-launch/27997
        // Atlas: https://sky-atlas.io/#fd030da6-1a4d-4df6-8e87-043d4b9666d5

        // Add 0x829dC2b7E94B1954F0764E573f2E0d45Afa28199 to the chainlog as PAU_BEACON
        DssExecLib.setChangelogAddress("PAU_BEACON", PAU_BEACON);

        // ---------- Transfer USDS from Amatsu SubProxy to SFF ----------
        // Forum: TODO
        // Atlas: https://sky-atlas.io/#06bac1e1-ae52-4c67-8ca9-0dcec22dddee

        // Add 0x5162489F4FEa651b76c75193387d08aAAC9CB52C to the chainlog as SUBPROXY_METHODS
        DssExecLib.setChangelogAddress("SUBPROXY_METHODS", SUBPROXY_METHODS);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.17");

        // Execute SUBPROXY_METHODS in AMATSU_SUBPROXY to transfer 14 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        SubProxyLike(AMATSU_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKY_FRONTIER_FOUNDATION, 14 * MILLION * WAD)
        );

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // TODO: add relevant content once exec sheet is updated

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-2-2026-proposed-changes-to-spark-for-upcoming-spell/27982
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.2.1.2.1
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xcd4642f0ada4ccb7d8ad744594dc1ea8051c5819724810b11aca042df6dd0a66
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x4f6d0c56862e4b66e006c8c363a8daa79df521af0964360016edd2bfb8a49178
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xbf91a06534d47861b5810c646ccc1560eb7730ff14ab1c16a1e0b92fc535a073
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x5f3a7d62d6d26c06890dd0300071d0f22cd4fdd7115c0d9c94577b90f644089c

        // Whitelist Spark spell with address 0xcc7529473B850103524905D3914470898aDe8747 and codehash 0xf952ba1ea1df8c42217cecd3c4e88abcde2864fbf1e4465b1a13af0bf05e00f0 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-2-2026-proposed-changes-to-grove-for-upcoming-spell/27976
        // Poll: https://vote.sky.money/polling/QmdXjfm6
        // Atlas: https://sky-atlas.io/#aa16daa3-ee62-49eb-851e-cb0708670144

        // Whitelist Grove spell with address 0xa21d2E301D50AfF797143deb5a7C400482E9122C and codehash 0xb3377dba77dfd8bce7c272e7c4c445ab48b3d0ec3fd0a52f512a39974f059a0f in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Skybase Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-2-2026-proposed-changes-to-skybase-for-upcoming-spell/27973
        // Poll: https://vote.sky.money/polling/QmdXjfm6

        // Whitelist Skybase spell with address 0xd3e4e16ED515Be794fd181D7d2cEB0447A6f2cb5 and codehash 0x09c387eed3e4373a4cc91fc28686e103cfc704335279f65f2f7308f474c002d9 in SKYBASE_STARGUARD, direct execution: No
        StarGuardLike(SKYBASE_STARGUARD).plot(SKYBASE_SPELL, SKYBASE_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
