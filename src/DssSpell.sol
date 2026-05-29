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
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { RwaUrnAbstract } from "dss-interfaces/dss/mip21/RwaUrnAbstract.sol";
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";

interface DssLitePsmLike {
    function rush() external view returns (uint256 wad);
    function fill() external returns (uint256 wad);
    function sellGemNoFee(address usr, uint256 gemAmt) external returns (uint256 daiOutWad);
}

interface RwaLiquidationLike {
    function tell(bytes32 ilk) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-06-04 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant MILLION  = 10 ** 6;
    uint256 internal constant BILLION  = 10 ** 9;
    uint256 internal constant WAD      = 10 ** 18;
    uint256 internal constant RAD      = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                   = DssExecLib.vat();
    address internal immutable USDC                      = DssExecLib.getChangelogAddress("USDC");
    address internal immutable MCD_LITE_PSM_USDC_A       = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable MCD_IAM_AUTO_LINE         = DssExecLib.getChangelogAddress("MCD_IAM_AUTO_LINE");
    address internal immutable RWA001_A_URN              = DssExecLib.getChangelogAddress("RWA001_A_URN");
    address internal immutable MIP21_LIQUIDATION_ORACLE  = DssExecLib.getChangelogAddress("MIP21_LIQUIDATION_ORACLE");
    address internal immutable MKR_SKY                   = DssExecLib.getChangelogAddress("MKR_SKY");

    function actions() public override {
        // ---------- RWA001-A Offboarding Spell 1 ----------

        // Temporarily update LITE-PSM-USDC-A AutoLine parameters
        // Call DssExecLib.setIlkAutoLineDebtCeiling with:
        // bytes32 ilk being "LITE-PSM-USDC-A";
        // uint256 amount being 10_014_319_144;
        DssExecLib.setIlkAutoLineDebtCeiling("LITE-PSM-USDC-A", 10_014_319_144);

        // Force the updated AutoLine parameters into the Vat debt ceiling
        // Call MCD_IAM_AUTO_LINE.exec with:
        // bytes32 ilk being "LITE-PSM-USDC-A"
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("LITE-PSM-USDC-A");

        // Fill the LITE-PSM-USDC-A DAI buffer
        // Call LITE_PSM_USDC_A.fill() only if LITE_PSM_USDC_A.rush() > 0
        if(DssLitePsmLike(MCD_LITE_PSM_USDC_A).rush() > 0) {
            DssLitePsmLike(MCD_LITE_PSM_USDC_A).fill();
        }

        // Approve LITE_PSM_USDC_A to pull USDC
        // Call USDC.approve with:
        // address spender being LITE_PSM_USDC_A;
        // uint256 amount being 14_319_143_510000, i.e. exactly 14,319,143.51 USDC using 6 decimals.
        GemAbstract(USDC).approve(MCD_LITE_PSM_USDC_A, 14_319_143_510000);

        // Convert returned USDC to DAI
        // Call LITE_PSM_USDC_A.sellGemNoFee with:
        // LITE_PSM_USDC_A being 0xf6e72Db5454dd049d0788e411b06CfAF16853042;
        // address usr being RWA001_A_URN;
        // uint256 gemAmt being 14_319_143_510000, i.e. exactly 14,319,143.51 USDC using 6 decimals
        uint256 daiOutWad = DssLitePsmLike(MCD_LITE_PSM_USDC_A).sellGemNoFee(RWA001_A_URN, 14_319_143_510000);

        // Restore the original LITE-PSM-USDC-A AutoLine parameters
        // Call DssExecLib.setIlkAutoLineDebtCeiling with:
        // bytes32 ilk being "LITE-PSM-USDC-A"
        // uint256 amount being 10_000_000_000
        DssExecLib.setIlkAutoLineDebtCeiling("LITE-PSM-USDC-A", 10_000_000_000);

        // Re-execute MCD_IAM_AUTO_LINE for LITE-PSM-USDC-A
        // Call MCD_IAM_AUTO_LINE.exec with:
        // bytes32 ilk being "LITE-PSM-USDC-A"
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("LITE-PSM-USDC-A");

        // Repay RWA001_A_URN debt
        // Call RWA001_A_URN.wipe with:
        // RWA001_A_URN being 0xa3342059BcDcFA57a13b12a35eD4BBE59B873005
        // uint256 wad being the DAI amount returned by LITE_PSM_USDC_A.sellGemNoFee(RWA001_A_URN, gemAmt).
        RwaUrnAbstract(RWA001_A_URN).wipe(daiOutWad);

        // Note: get the current `line` from the Vat to decrease the global debt ceiling
        (,,, uint256 line,) = VatAbstract(MCD_VAT).ilks("RWA001-A");

        // Set the RWA001-A debt ceiling to zero
        // Call DssExecLib.setIlkDebtCeiling with:
        // bytes32 ilk being "RWA001-A"
        // uint256 amount being 0
        DssExecLib.setIlkDebtCeiling("RWA001-A", 0);

        // Note: Reduce the global debt ceiling by the same amount as previous line
        DssExecLib.decreaseGlobalDebtCeiling(line / RAD);

        // Start soft liquidation
        // Call MIP21_LIQUIDATION_ORACLE.tell with:
        // MIP21_LIQUIDATION_ORACLE being 0x88f88Bb9E66241B73B84f3A6E197FbBa487b1E30
        // bytes32 ilk being "RWA001-A"
        RwaLiquidationLike(MIP21_LIQUIDATION_ORACLE).tell("RWA001-A");

        // ---------- Keeper Network Adjustments ----------

        // TODO

        // ---------- ALLOCATOR-SPARK-A DC-IAM Parameter Updates ----------

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-SPARK-A",
            // Increase gap by 1 billion USDS from 500 million USDS to 1.5 billion USDS
            _gap: 1500 * MILLION,
            // Decrease ttl by 12 hours from 24 hours to 12 hours
            _ttl: 12 hours,
            // Keep line unchanged at 10 billion USDS
            _amount: 10 * BILLION
        });

        // ---------- MKR-SKY Delayed Upgrade Penalty Increase ----------

        // Increase the Delayed Upgrade Penalty for MKR-SKY conversions by 1 percentage point from 3% to 4%
        DssExecLib.setValue(MKR_SKY, "fee", 4 * WAD / 100);

        // ---------- Spark Proxy Spell ----------

        // TODO

        // ---------- Grove Proxy Spell ----------

        // TODO

    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
