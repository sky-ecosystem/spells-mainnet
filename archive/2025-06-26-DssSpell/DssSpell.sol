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
// import "dss-exec-lib/DssAction.sol";
import {DssExecLib} from "dss-exec-lib/DssExecLib.sol";

import {GemAbstract} from "dss-interfaces/ERC/GemAbstract.sol";
import {VestAbstract} from "dss-interfaces/dss/VestAbstract.sol";
import {MCD, DssInstance} from "dss-test/MCD.sol";

import {StakingRewardsInit, StakingRewardsInitParams} from "./dependencies/endgame-toolkit/StakingRewardsInit.sol";
import {VestInit, VestCreateParams} from "./dependencies/endgame-toolkit/VestInit.sol";
import {VestedRewardsDistributionInit, VestedRewardsDistributionInitParams} from "./dependencies/endgame-toolkit/VestedRewardsDistributionInit.sol";

import {SkyInit} from "./dependencies/sky/SkyInit.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface VestedRewardsDistributionLike {
    function distribute() external;
}

interface VestedRewardsDistributionJobLike {
    function set(address dist, uint256 period) external;
}

interface LockstakeEngineLike {
    function addFarm(address farm) external;
}

interface MkrSkyLike {
    function mkrToSky(address usr, uint256 mkrAmt) external;
}

interface BurnLike {
    function burn(address, uint256) external;
}

interface StakingRewardsLike {
    function setRewardsDuration(uint256) external;
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
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
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/2ee633d82b2dfea35386b6bbd060db2df50a5d67/2025/executive-vote-2025-06-26-SPK-farming-MKR-to-SKY-partial-upgrade-phase-three.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-06-26 MakerDAO Executive Spell | Hash: 0x921afc55c9b3a3563926da63687b00b1b751cf540052d71356ef62107d06f2c8";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Set earliest execution date June 30, 14:00 UTC ----------

    // Note: 2025-06-30T14:00:00Z
    uint256 constant internal JUN_30_2025_14_00_UTC = 1751292000;

    // Note: Override nextCastTime to inform keepers about the earliest execution time
    function nextCastTime(uint256 eta) external view override returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        // Note: First calculate the standard office hours cast time
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
        // Note: Then ensure it's not before our minimum date
        return castTime < JUN_30_2025_14_00_UTC ? JUN_30_2025_14_00_UTC : castTime;
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

    // ---------- Contracts ----------
    address internal immutable DAI                   = DssExecLib.dai();
    address internal immutable CRON_REWARDS_DIST_JOB = DssExecLib.getChangelogAddress("CRON_REWARDS_DIST_JOB");
    address internal immutable LOCKSTAKE_ENGINE      = DssExecLib.getChangelogAddress("LOCKSTAKE_ENGINE");
    address internal immutable MKR_SKY               = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable MCD_VEST_MKR_TREASURY = DssExecLib.getChangelogAddress("MCD_VEST_MKR_TREASURY");
    address internal immutable MKR                   = DssExecLib.getChangelogAddress("MKR");
    address internal immutable SKY                   = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MCD_SPLIT             = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable REWARDS_LSSKY_USDS    = DssExecLib.getChangelogAddress("REWARDS_LSSKY_USDS");
    address internal immutable DAI_USDS              = DssExecLib.getChangelogAddress("DAI_USDS");

    address internal constant SPK                    = 0xc20059e0317DE91738d13af027DfC4a50781b066;
    address internal constant MCD_VEST_SPK_TREASURY  = 0xF9A2002b471f600A5484da5a735a2A053d377078;
    address internal constant REWARDS_USDS_SPK       = 0x173e314C7635B45322cd8Cb14f44b312e079F3af;
    address internal constant REWARDS_DIST_USDS_SPK  = 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c;
    address internal constant REWARDS_LSSKY_SPK      = 0x99cBC0e4E6427F6939536eD24d1275B95ff77404;
    address internal constant REWARDS_DIST_LSSKY_SPK = 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e;

    // ---------- Wallets ----------
    address internal constant LAUNCH_PROJECT_FUNDING = 0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F;
    address internal constant BLUE                   = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA            = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2               = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant PBG                    = 0x8D4df847dB7FfE0B46AF084fE031F7691C6478c2;
    address internal constant JULIACHANG             = 0x252abAEe2F4f4b8D39E5F12b163eDFb7fac7AED7;
    address internal constant EXCEL                  = 0x0F04a22B62A26e25A29Cba5a595623038ef7AcE7;
    address internal constant WBC                    = 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47;
    address internal constant CLOAKY_KOHLA_2         = 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a;

    // ---------- Math ----------
    uint256 internal constant WAD = 10 ** 18;

    // ---------- Execute Spark Proxy Spell ----------
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0x74e1ba852C864d689562b5977EedCB127fDE0C9F;

    function actions() public override {
        // Set earliest execution date June 30, 14:00 UTC
        require(block.timestamp >= JUN_30_2025_14_00_UTC, "Spell can only be cast after June 30, 2025, 14:00 UTC");

        // ---------- SPK Farms ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-spk-farms/26703
        // Atlas: https://sky-atlas.powerhouse.io/A.2.9.1.2.2.1.2.2.2_Spark_Token_Reward_Distribution_Schedule/1fef2ff0-8d73-809d-ac41-eb9753c05d41|9e1f80092582d59891b002d4366698bb

        // ---------- Initialize the SPK vest: ----------

        // Approve MCD_VEST_SPK_TREASURY to spend SPK in the treasury:
        // spender: 0xF9A2002b471f600A5484da5a735a2A053d377078
        // amount: 3_250_000_000 * WAD
        GemAbstract(SPK).approve(MCD_VEST_SPK_TREASURY, 3_250_000_000 * WAD);

        // Set cap in MCD_VEST_SPK_TREASURY:
        // target: 0xF9A2002b471f600A5484da5a735a2A053d377078
        // what: "cap"
        // amt: 2_502_500_000 * WAD / 730 days
        DssExecLib.setValue(MCD_VEST_SPK_TREASURY, "cap", 2_502_500_000 * WAD / 730 days);

        // Add MCD_VEST_SPK_TREASURY to the Chainlog:
        // key: "MCD_VEST_SPK_TREASURY"
        // addr: 0xF9A2002b471f600A5484da5a735a2A053d377078
        DssExecLib.setChangelogAddress("MCD_VEST_SPK_TREASURY", MCD_VEST_SPK_TREASURY);

        // Add SPK to the Chainlog:
        // key: "SPK"
        // addr: 0xC20059E0317De91738D13Af027DfC4a50781b066
        DssExecLib.setChangelogAddress("SPK", SPK);

        // ---------- USDS to SPK Farm ----------

        // Initialize the USDS to SPK farm:
        // Create the vesting stream for the USDS to SPK farm:
        // vest: 0xF9A2002b471f600A5484da5a735a2A053d377078
        // p.usr: 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c
        // p.tot: 2_275_000_000 * WAD
        // p.bgn: block.timestamp - 7 days
        // p.tau: 730 days
        // p.eta: 0
        // restricted: true
        uint256 vestIdUsdsSpk = VestInit.create(
            MCD_VEST_SPK_TREASURY,
            VestCreateParams({
                usr: REWARDS_DIST_USDS_SPK,
                tot: 2_275_000_000 * WAD,
                bgn: block.timestamp - 7 days,
                tau: 730 days,
                eta: 0
            })
        );

        // Initialize REWARDS_USDS_SPK:
        // rewards: 0x173e314C7635B45322cd8Cb14f44b312e079F3af
        // p.dist: 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c
        // duration: 7 days
        StakingRewardsInit.init(
            REWARDS_USDS_SPK,
            StakingRewardsInitParams({ dist: REWARDS_DIST_USDS_SPK })
        );

        // Initialize REWARDS_DIST_USDS_SPK:
        // dist: 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c
        // p.vestId: {vestIdUsdsSpk}
        VestedRewardsDistributionInit.init(
            REWARDS_DIST_USDS_SPK,
            VestedRewardsDistributionInitParams({ vestId: vestIdUsdsSpk })
        );

        // Call distribute() on REWARDS_DIST_USDS_SPK
        VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).distribute();

        // Add REWARDS_DIST_USDS_SPK to CRON_REWARDS_DIST_JOB:
        // dist: 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c
        // period: 7 days - 1 hours
        VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).set(REWARDS_DIST_USDS_SPK, 7 days - 1 hours);

        // Add REWARDS_USDS_SPK and REWARDS_DIST_USDS_SPK to the Chainlog:
        // key: "REWARDS_USDS_SPK"
        // addr: 0x173e314C7635B45322cd8Cb14f44b312e079F3af
        // key: "REWARDS_DIST_USDS_SPK"
        // addr: 0x3959e23A63CA7ac12D658bb44F90cb1f7Ee4C02c
        DssExecLib.setChangelogAddress("REWARDS_USDS_SPK", REWARDS_USDS_SPK);
        DssExecLib.setChangelogAddress("REWARDS_DIST_USDS_SPK", REWARDS_DIST_USDS_SPK);

        // ---------- LSSKY to SPK Farm ----------

        // Initialize the LSSKY to SPK farm:
        // Create the vesting stream for the LSSKY to SPK farm:
        // vest: 0xF9A2002b471f600A5484da5a735a2A053d377078
        // p.usr: 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e
        // p.tot: 975_000_000 * WAD
        // p.bgn: block.timestamp - 7 days
        // p.tau: 730 days
        // p.eta: 0
        // restricted: true
        uint256 vestIdLsskySpk = VestInit.create(
            MCD_VEST_SPK_TREASURY,
            VestCreateParams({
                usr: REWARDS_DIST_LSSKY_SPK,
                tot: 975_000_000 * WAD,
                bgn: block.timestamp - 7 days,
                tau: 730 days,
                eta: 0
            })
        );

        // Initialize REWARDS_LSSKY_SPK:
        // rewards: 0x99cBC0e4E6427F6939536eD24d1275B95ff77404
        // p.dist: 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e
        // duration: 7 days
        StakingRewardsInit.init(
            REWARDS_LSSKY_SPK,
            StakingRewardsInitParams({ dist: REWARDS_DIST_LSSKY_SPK })
        );

        // Initialize REWARDS_DIST_LSSKY_SPK:
        // dist: 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e
        // p.vestId: vestIdLsskySpk
        VestedRewardsDistributionInit.init(
            REWARDS_DIST_LSSKY_SPK,
            VestedRewardsDistributionInitParams({ vestId: vestIdLsskySpk })
        );

        // Call distribute() on REWARDS_DIST_LSSKY_SPK
        VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).distribute();

        // Add REWARDS_DIST_LSSKY_SPK to CRON_REWARDS_DIST_JOB:
        // dist: 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e
        // period: 7 days - 1 hours
        VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).set(REWARDS_DIST_LSSKY_SPK, 7 days - 1 hours);

        // Add REWARDS_LSSKY_SPK farm to the Lockstake Engine:
        // farm: 0x99cBC0e4E6427F6939536eD24d1275B95ff77404
        LockstakeEngineLike(LOCKSTAKE_ENGINE).addFarm(REWARDS_LSSKY_SPK);

        // Add REWARDS_LSSKY_SPK and REWARDS_DIST_LSSKY_SPK to the Chainlog:
        // key: "REWARDS_LSSKY_SPK"
        // addr: 0x99cBC0e4E6427F6939536eD24d1275B95ff77404
        // key: "REWARDS_DIST_LSSKY_SPK"
        // addr: 0xa3Ee378BdD0b7DD403cEd3a0A65B2B389A2eaB7e
        DssExecLib.setChangelogAddress("REWARDS_LSSKY_SPK", REWARDS_LSSKY_SPK);
        DssExecLib.setChangelogAddress("REWARDS_DIST_LSSKY_SPK", REWARDS_DIST_LSSKY_SPK);

        // ---------- Convert MKR balance of the PauseProxy to SKY ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-june-26-spell/26710
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.1.4.2.3_Upgrade_MKR_In_Pause_Proxy_To_SKY/1f1f2ff0-8d73-8064-ab0e-d51c96127c19|b341f4c0b83472dc1f9e1a3b

        // Note: get unpaid MKR for MCD_VEST_MKR_TREASURY ids 9, 18, 24, 35, 37, and 39
        uint256 unpaidMkr = VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(9) +
            VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(18) +
            VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(24) +
            VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(35) +
            VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(37) +
            VestAbstract(MCD_VEST_MKR_TREASURY).unpaid(39);

        // Note: approve MKR_SKY to spend MKR balance of the PauseProxy
        GemAbstract(MKR).approve(MKR_SKY, GemAbstract(MKR).balanceOf(address(this)) - unpaidMkr);

        // Call mkrToSky() on MKR_SKY with the MKR balance of the PauseProxy minus the unpaid() MKR for MCD_VEST_MKR_TREASURY ids 9, 18, 24, 35, 37, and 39
        MkrSkyLike(MKR_SKY).mkrToSky(address(this), GemAbstract(MKR).balanceOf(address(this)) - unpaidMkr);

        // ---------- Disable MKR_SKY_LEGACY Converter ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-june-26-spell/26710
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.2.4.2.1_Disabling_Legacy_Conversion_Contract/210f2ff0-8d73-80d4-a983-f9217c9b244a|b341f4c0b834477b310e7381

        // Note: load DssInstance from chainlog
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Call disableOldConverterMkrSky() to deactivate the legacy converter (https://github.com/sky-ecosystem/sky/pull/21/files#diff-f6cbf09833eed835c52b0a1c5be7dd9e84213d278c958843725af6a77faa77d4R69-R75)
        SkyInit.disableOldConverterMkrSky(dss);

        // ---------- Burn Excess SKY from MKR_SKY Converter ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-june-26-spell/26710
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.2.4.2_MKR_To_SKY_Conversion_Emissions/209f2ff0-8d73-80c7-80e7-e61690dc7381|b341f4c0b834477b310e

        // Call burnExtraSky() to burn excess pre-minted SKY in the new MKR_SKY converter (https://github.com/sky-ecosystem/sky/pull/21/files#diff-f6cbf09833eed835c52b0a1c5be7dd9e84213d278c958843725af6a77faa77d4R81-R88)
        SkyInit.burnExtraSky(dss);

        // ---------- Burn SKY held in PauseProxy ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-june-26-spell/26710
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.2.4.1_SKY_Token_Rewards_Emissions/209f2ff0-8d73-80ee-bc70-f5cbed9c2664|b341f4c0b834477b310e

        // Burn 426,292,860.23 SKY from the PauseProxy
        // Note: `ether` is only used as a keyword. Only SKY is being burned.
        BurnLike(SKY).burn(address(this), 426_292_860.23 ether);

        // ---------- vow.hump Reduction ----------
        // Forum: https://forum.sky.money/t/smart-burn-engine-parameter-update-proposals-june-26-2025-spell-contents/26702

        // Reduce vow.hump by 20 million USDS from 70 million USDS to 50 million USDS
        DssExecLib.setSurplusBuffer(50_000_000);

        // ---------- Splitter.hop Increase ----------
        // Forum: https://forum.sky.money/t/smart-burn-engine-parameter-update-proposals-june-26-2025-spell-contents/26702
        // Forum: https://forum.sky.money/t/smart-burn-engine-parameter-update-proposals-june-26-2025-spell-contents/26702/3

        // Increase splitter.hop by 432 seconds, from 1,728 seconds to 2,160 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 2_160);

        // Increase rewardsDuration in REWARDS_LSSKY_USDS by 432 seconds from 1,728 seconds to 2,160 seconds
        StakingRewardsLike(REWARDS_LSSKY_USDS).setRewardsDuration(2_160);

        // ---------- Increase ALLOCATOR-BLOOM-A Maximum Debt Ceiling ----------
        // Forum: https://forum.sky.money/t/parameter-changes-proposal-june-16-2025/26653
        // Poll: https://vote.sky.money/polling/Qmcy6Lug

        // Increase the Maximum Debt Ceiling (line) by 2.4 billion USDS, from 100 million USDS to 2.5 billion USDS
        DssExecLib.setIlkAutoLineDebtCeiling("ALLOCATOR-BLOOM-A", 2_500_000_000);

        // ---------- Spark USDS Transfer ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-06-23/26701

        // Transfer 20,600,000 USDS to the Spark SubProxy (0x3300f198988e4C9C63F75dF86De36421f06af8c4)
        _transferUsds(SPARK_PROXY, 20_600_000 * WAD);

        // ---------- Launch Project Funding ----------
        // Forum: https://forum.sky.money/t/utilization-of-the-launch-project-under-the-accessibility-scope/21468/46
        // Atlas: https://sky-atlas.powerhouse.io/A.5.6_Launch_Project/1f433d9d-7cdb-406f-b7e8-f9bc4855eb77%7C8d5a

        // Transfer 8,400,000 SKY to 0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F
        GemAbstract(SKY).transfer(LAUNCH_PROJECT_FUNDING, 8_400_000 * WAD);

        // ---------- Delegate Compensation for May 2025 ----------
        // Forum: https://forum.sky.money/t/may-2025-aligned-delegate-compensation/26698
        // Atlas: https://sky-atlas.powerhouse.io/Budget_And_Participation_Requirements/4c698938-1a11-4486-a568-e54fc6b0ce0c|0db3af4e

        // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE,        4_000 * WAD);

        // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2,    4_000 * WAD);

        // PBG - 4,000 USDS - 0x8D4df847dB7FfE0B46AF084fE031F7691C6478c2
        _transferUsds(PBG,         4_000 * WAD);

        // JuliaChang - 2,323 USDS - 0x252abAEe2F4f4b8D39E5F12b163eDFb7fac7AED7
        _transferUsds(JULIACHANG,  2_323 * WAD);

        // Excel - 1,088 USDS - 0x0F04a22B62A26e25A29Cba5a595623038ef7AcE7
        _transferUsds(EXCEL,       1_088 * WAD);

        // WBC - 1,032 USDS - 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47
        _transferUsds(WBC,         1_032 * WAD);

        // ---------- Atlas Core Development USDS Payments for June 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-june-2025/26585
	    // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-june-2025/26585/7
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1.1_Funding/8ea8dcb0-7261-4c1a-ae53-b7f3eb5362e5%7C9e1f3b569af1

        // BLUE - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // Kohla - 11,000 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a
        _transferUsds(CLOAKY_KOHLA_2, 11_000 * WAD);

        // ---------- Atlas Core Development SKY Payments for June 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-june-2025/26585
	    // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-june-2025/26585/7
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1.1_Funding/8ea8dcb0-7261-4c1a-ae53-b7f3eb5362e5%7C9e1f3b569af1

        // BLUE - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

        // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // Note: bump chainlog version because of new contracts being added and some being removed
        DssExecLib.setChangelogVersion("1.20.2");

        // ---------- Execute Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/june-26-2025-proposed-changes-to-spark-for-upcoming-spell/26663
        // Poll: https://vote.sky.money/polling/QmcGPTMX
        // Poll: https://vote.sky.money/polling/QmWtGgPH

        // Execute Spark Proxy Spell at address 0x74e1ba852C864d689562b5977EedCB127fDE0C9F
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));
    }

    // ---------- Helper Functions ----------

    /// @notice wraps the operations required to transfer USDS from the surplus buffer.
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
