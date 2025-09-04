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

import {MCD, DssInstance} from "dss-test/MCD.sol";
import {LockstakeInit} from "./dependencies/lockstake/LockstakeInit.sol";
import {StUsdsInit, StUsdsConfig, StUsdsInstance} from "./dependencies/stusds/StUsdsInit.sol";
import {IlkRegistryAbstract} from "dss-interfaces/dss/IlkRegistryAbstract.sol";
import {VatAbstract} from "dss-interfaces/dss/VatAbstract.sol";
import {VestAbstract} from "dss-interfaces/dss/VestAbstract.sol";
import {GemAbstract} from "dss-interfaces/ERC/GemAbstract.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface RateSetterLike {
    function maxLine() external view returns (uint256);
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256);
}

interface DaiUsdsLike {
    function daiToUsds(address, uint256) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/7201ee0a23b0c5a85e0c1ba44226900aa3bb45a8/2025/executive-vote-2025-09-04-stusds-onboarding.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-09-04 MakerDAO Executive Spell | Hash: 0x4e5cc173855cacdb606cb69c57889ec7d3b5f95378b9c6ab786ce36c0de3c1a5";

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
    uint256 internal constant RAD = 10 ** 45;

    // ---------- Contracts ----------
    address internal constant LOCKSTAKE_CLIP = 0x836F56750517b1528B5078Cba4Ac4B94fBE4A399;
    address internal constant STUSDS = 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9;
    address internal constant STUSDS_IMP = 0x7A61B7adCFD493f7CF0F86dFCECB94b72c227F22;
    address internal constant STUSDS_RATE_SETTER = 0x30784615252B13E1DbE2bDf598627eaC297Bf4C5;
    address internal constant STUSDS_MOM = 0xf5DEe2CeDC5ADdd85597742445c0bf9b9cAfc699;
    address internal constant STUSDS_RATE_SETTER_BUD = 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16;

    address internal immutable ILK_REGISTRY = DssExecLib.reg();
    address internal immutable MCD_VAT = DssExecLib.vat();
    address internal immutable DAI = DssExecLib.dai();
    address internal immutable REWARDS_DIST_USDS_SKY = DssExecLib.getChangelogAddress("REWARDS_DIST_USDS_SKY");
    address internal immutable MCD_VEST_SKY_TREASURY = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable SKY = DssExecLib.getChangelogAddress("SKY");
    address internal immutable DAI_USDS = DssExecLib.getChangelogAddress("DAI_USDS");

    // ---------- Wallets ----------
    address internal constant LIQUIDITY_BOOTSTRAPPING = 0xD8507ef0A59f37d15B5D7b630FA6EEa40CE4AFdD;
    address internal constant ECOSYSTEM_TEAM = 0x05F471262d15EECA4059DadE070e5BEd509a4e73;

    // ---------- Spark Proxy Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0xe7782847eF825FF37662Ef2F426f2D8c5D904121;

    function actions() public override {
        // ----- stUSDS Onboarding -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-09-01/27122
        // Poll: https://vote.sky.money/polling/QmQwTjgE

        // Note: Load DssInstance from chainlog
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // ----- Update LSEV2-SKY-A clipper by calling LockstakeInit.updateClipper with the following parameters: -----
        // Forum: https://forum.sky.money/t/technical-scope-of-the-stusds-module-launch/27129

        LockstakeInit.updateClipper(
            dss,
            // clipper_ being LockstakeClipper at 0x836F56750517b1528B5078Cba4Ac4B94fBE4A399
            LOCKSTAKE_CLIP,
            // cuttee being ERC1967Proxy for StUsds at 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9
            STUSDS
        );

        // ----- Initialize stUSDS module by calling StUsdsInit.init with the following parameters: -----

        StUsdsInstance memory stUsdsInstance = StUsdsInstance({
            // instance.stUsds being ERC1967Proxy for StUsds at 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9
            stUsds: STUSDS,
            // instance.stUsdsImp being StUsds implementation at 0x7A61B7adCFD493f7CF0F86dFCECB94b72c227F22
            stUsdsImp: STUSDS_IMP,
            // instance.rateSetter being StUsdsRateSetter at 0x30784615252B13E1DbE2bDf598627eaC297Bf4C5
            rateSetter: STUSDS_RATE_SETTER,
            // instance.mom being StUsdsMom at 0xf5DEe2CeDC5ADdd85597742445c0bf9b9cAfc699
            mom: STUSDS_MOM
        });

        // Note: Declare memory array buds for stUsds config
        address[] memory buds = new address[](1);
        buds[0] = STUSDS_RATE_SETTER_BUD;

        StUsdsConfig memory stUsdsConfig = StUsdsConfig({
            // cfg.clip being LockstakeClipper at 0x836F56750517b1528B5078Cba4Ac4B94fBE4A399
            clip: LOCKSTAKE_CLIP,
            // cfg.str being 0 basis points
            str: RAY, // Note: 0 basis points == 1 RAY (per second rate)
            // cfg.cap being 200,000,000 USDS
            cap: 200_000_000 * WAD,
            // cfg.line being 200,000,000 USDS
            line: 200_000_000 * RAD,
            // cfg.tau being 57,600 seconds
            tau: 57_600,
            // cfg.maxLine being 1,000,000,000 USDS
            maxLine: 1_000_000_000 * RAD,
            // cfg.maxCap being 1,000,000,000 USDS
            maxCap: 1_000_000_000 * WAD,
            // cfg.minStrBps being 200 basis points
            minStrBps: 200,
            // cfg.maxStrBps being 5,000 basis points
            maxStrBps: 5_000,
            // cfg.stepStrBps being 4,000 basis points
            stepStrBps: 4_000,
            // cfg.minDutyBps being 210 basis points
            minDutyBps: 210,
            // cfg.maxDutyBps being 5,000 basis points
            maxDutyBps: 5_000,
            // cfg.stepDutyBps being 4,000 basis points
            stepDutyBps: 4_000,
            // cfg.buds being 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16
            buds: buds
        });

        // Note: Initialize stUSDS module by calling StUsdsInit.init
        StUsdsInit.init(dss, stUsdsInstance, stUsdsConfig);

        // ----- Increase global vat.Line -----

        // set vat.Line to sum(max(debt, line)) for all other ilks + max(LSEV2-SKY-A debt, stUSDS BEAM maxLine)
        DssExecLib.setGlobalDebtCeiling(_calculateLine() / RAD);

        // Note: Bump chainlog PATCH version
        DssExecLib.setChangelogVersion("1.20.4");

        // ----- SKY Token Rewards Rebalance -----
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/14
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/15

        // Yank MCD_VEST_SKY_TREASURY vest with ID 5
        VestAbstract(MCD_VEST_SKY_TREASURY).yank(5);

        // VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY
        // Note: `distribute()` only needs to be called if it wasn't already, otherwise it reverts
        if (VestAbstract(MCD_VEST_SKY_TREASURY).unpaid(5) > 0) {
            VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).distribute();
        }

        // ----- Deploy new MCD_VEST_SKY_TREASURY stream with the following parameters: -----

        // res: 1 (restricted)
        // Note: Action taken below, after stream creation

        // Increase SKY allowance for MCD_VEST_SKY_TREASURY to the sum of all streams
        GemAbstract(SKY).approve(
            MCD_VEST_SKY_TREASURY,
            VestAbstract(MCD_VEST_SKY_TREASURY).tot(1) - VestAbstract(MCD_VEST_SKY_TREASURY).rxd(1)
                + VestAbstract(MCD_VEST_SKY_TREASURY).tot(2) - VestAbstract(MCD_VEST_SKY_TREASURY).rxd(2)
                + VestAbstract(MCD_VEST_SKY_TREASURY).tot(3) - VestAbstract(MCD_VEST_SKY_TREASURY).rxd(3)
                + VestAbstract(MCD_VEST_SKY_TREASURY).tot(4) - VestAbstract(MCD_VEST_SKY_TREASURY).rxd(4) + 76_739_938 * WAD
        );

        // MCD_VEST_SKY_TREASURY Vest Stream  | from 'block.timestamp' to 'block.timestamp + 15,724,800 seconds' | 76,739,938 * WAD SKY | REWARDS_DIST_USDS_SKY
        uint256 vestId = VestAbstract(MCD_VEST_SKY_TREASURY).create(
            REWARDS_DIST_USDS_SKY, 76_739_938 * WAD, block.timestamp, 15_724_800, 0, address(0)
        );

        // Note: Restrict = 1, per the instruction on the top of this section
        VestAbstract(MCD_VEST_SKY_TREASURY).restrict(vestId);

        // File the new stream ID on REWARDS_DIST_USDS_SKY
        DssExecLib.setValue(REWARDS_DIST_USDS_SKY, "vestId", vestId);

        // ----- Core Simplification Buffer Budget Transfer -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-09-01/27122
        // Poll: https://vote.sky.money/polling/QmQwTjgE

        // Transfer 8,000,000 USDS to 0xd8507ef0a59f37d15b5d7b630fa6eea40ce4afdd
        _transferUsds(LIQUIDITY_BOOTSTRAPPING, 8_000_000 * WAD);

        // ----- Accessibility Reward Budget Transfer -----
        // Forum: https://forum.sky.money/t/utilization-of-the-accessibility-reward-budget-a-2-4/27131
        // Poll: https://vote.sky.money/polling/QmXRwLEu

        // Transfer 3,000,000 USDS to 0x05F471262d15EECA4059DadE070e5BEd509a4e73
        _transferUsds(ECOSYSTEM_TEAM, 3_000_000 * WAD);

        // ----- Execute Spark Proxy Spell -----
        // Forum: https://forum.sky.money/t/september-4-2025-proposed-changes-to-spark-for-upcoming-spell/27102
        // Poll: https://vote.sky.money/polling/QmeLKi1N
        // Poll: https://vote.sky.money/polling/QmXDwbcJ
        // Poll: https://vote.sky.money/polling/QmRLrw8X
        // Poll: https://vote.sky.money/polling/QmTS1Jw7
        // Poll: https://vote.sky.money/polling/QmUKs4Lt
        // Poll: https://vote.sky.money/polling/QmNbTb5v
        // Poll: https://vote.sky.money/polling/QmbSeE7t
        // Poll: https://vote.sky.money/polling/QmbHt4Vg
        // Atlas: https://sky-atlas.powerhouse.io/A.2.9.1.2.2.5.4.1_Initial_Cash_Grant_To_Spark_Foundation/21ff2ff0-8d73-8018-be75-c28cee3dddb7%7C9e1f80092582d59891b0d93ee881

        // Execute Spark proxy spell at 0xe7782847eF825FF37662Ef2F426f2D8c5D904121
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));
    }

    // ---------- Helper Functions ----------

    /// @notice Returns the global debt ceiling using the governance agreed formula
    /// @notice sum(max(debt, line)) for all other ilks + max(LSEV2-SKY-A debt, stUSDS BEAM maxLine)
    function _calculateLine() internal view returns (uint256 _line) {
        bytes32[] memory ilks = IlkRegistryAbstract(ILK_REGISTRY).list();

        for (uint256 i; i < ilks.length; i++) {
            (uint256 Art, uint256 rate,, uint256 line,) = VatAbstract(MCD_VAT).ilks(ilks[i]);

            if (ilks[i] == "LSEV2-SKY-A") {
                _line += _max(Art * rate, RateSetterLike(STUSDS_RATE_SETTER).maxLine());
            } else {
                _line += _max(Art * rate, line);
            }
        }
    }

    /// @notice Returns max of two inputs
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

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
