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

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface RateSetterLike {
    function maxLine() external returns (uint256);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-09-04 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant BILLION = 10 ** 9;

    // ---------- Contracts ----------
    address internal constant LOCKSTAKE_CLIP = 0x836F56750517b1528B5078Cba4Ac4B94fBE4A399;
    address internal constant STUSDS = 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9;
    address internal constant STUSDS_IMP = 0x7A61B7adCFD493f7CF0F86dFCECB94b72c227F22;
    address internal constant STUSDS_RATE_SETTER = 0x30784615252B13E1DbE2bDf598627eaC297Bf4C5;
    address internal constant STUSDS_MOM = 0xf5DEe2CeDC5ADdd85597742445c0bf9b9cAfc699;
    address internal constant STUSDS_RATE_SETTER_BUD = 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16;
    address internal constant ILK_REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant MCD_VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;

    function actions() public override {
        // ----- stUSDS Onboarding -----

        // Note: load DssInstance from chainlog
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // ----- Update LSEV2-SKY-A clipper by calling LockstakeInit.updateClipper with the following parameters: -----
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
            stUsds: 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9,
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
            cap: 200 * MILLION * WAD,
            // cfg.line being 200,000,000 USDS
            line: 200 * MILLION * RAD,
            // cfg.tau being 57,600 seconds
            tau: 57_600,
            // cfg.maxLine being 1,000,000,000 USDS
            maxLine: 1 * BILLION * RAD,
            // cfg.maxCap being 1,000,000,000 USDS
            maxCap: 1 * BILLION * WAD,
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

        // Yank MCD_VEST_SKY vest with ID 5
        // VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY

        // ----- Deploy new MCD_VEST_SKY_TREASURY stream with the following parameters: -----

        // res: 1 (restricted)
        // Increase SKY allowance for MCD_VEST_SKY_TREASURY to the sum of all streams
        // MCD_VEST_SKY_TREASURY Vest Stream  | from 'block.timestamp' to 'block.timestamp + 15,724,800 seconds' | 76,739,938 * WAD SKY | REWARDS_DIST_USDS_SKY
        // File the new stream ID on REWARDS_DIST_USDS_SKY

        // ----- Core Simplification Buffer Budget Transfer -----

        // Transfer 8,000,000 USDS to 0xd8507ef0a59f37d15b5d7b630fa6eea40ce4afdd

        // ----- Accessibility Reward Budget Transfer -----

        // Transfer 3,000,000 USDS to 0x05F471262d15EECA4059DadE070e5BEd509a4e73

        // ----- Execute Spark Proxy Spell -----

        // Execute Spark proxy spell at TBD
    }

    // ---------- Helper Functions ----------

    /// @notice Returns the global debt ceiling using the governance agreed formula
    /// @notice sum(max(debt, line)) for all other ilks + max(LSEV2-SKY-A debt, stUSDS BEAM maxLine)
    function _calculateLine() internal returns (uint256 _line) {
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

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
