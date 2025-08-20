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

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/51170397cdb879918c477c9f0b27121802b5b963/2025/executive-vote-2025-08-21.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-08-21 MakerDAO Executive Spell | Hash: 0xd625577ce9db75bac5c2f7d1e6bda646af402a2b43aee4865ba1f8c7eb641dae";

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
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;
    uint256 internal constant RAY     = 10 ** 27;

    // ---------- Addresses ----------
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable MCD_SPOT                = DssExecLib.spotter();
    address internal immutable MCD_VEST_SKY_TREASURY   = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable REWARDS_DIST_USDS_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_USDS_SKY");
    address internal immutable SKY                     = DssExecLib.getChangelogAddress("SKY");
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_SPLIT               = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable MCD_CLIP_UNIV2DAIUSDC_A = DssExecLib.getChangelogAddress("MCD_CLIP_UNIV2DAIUSDC_A");

    // ---------- ERC-20 Tokens ----------
    address internal constant UNIV2USDSSKY = 0x2621CC0B3F3c079c1Db0E80794AA24976F0b9e3c;
    address internal constant ENS          = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
    address internal constant STAAVE       = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
    address internal constant COMP         = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address internal constant AAVE         = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address internal constant ETH          = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ---------- Wallets ----------
    address internal constant AAVE_V3_TREASURY         = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;
    address internal constant BLUE                     = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA              = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2                 = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant CLOAKY_KOHLA_2           = 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a;
    address internal constant EXCEL                    = 0x0F04a22B62A26e25A29Cba5a595623038ef7AcE7;
    address internal constant FORTIFICATION_FOUNDATION = 0x483413ccCD796Deddee88E4d3e202425d5E891C6;
    address internal constant SKY_FRONTIER_FOUNDATION  = 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0;
    address internal constant LIQUIDITY_BOOTSTRAPPING  = 0xD8507ef0A59f37d15B5D7b630FA6EEa40CE4AFdD;
    address internal constant PBG                      = 0x8D4df847dB7FfE0B46AF084fE031F7691C6478c2;
    address internal constant TANGO                    = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant WBC                      = 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47;

    // ---------- Grove Proxy Spell ----------
    // Note: The deployment address for the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant GROVE_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;
    address internal constant GROVE_SPELL = 0xFa533FEd0F065dEf8dcFA6699Aa3d73337302BED;

    // ---------- Spark Proxy Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0xa57d3ea3aBAbD57Ed1a1d91CD998a68FB490B95E;

    function actions() public override {
        // ---------- Fortification Foundation Grant ----------
        // Forum: https://forum.sky.money/t/weekly-cycle-atlas-edit-proposal-week-starting-2025-08-11/27008
        // Poll: https://vote.sky.money/polling/Qmeba6D9

        // Transfer 10,000,000 USDS to 0x483413ccCD796Deddee88E4d3e202425d5E891C6
        _transferUsds(FORTIFICATION_FOUNDATION, 10_000_000 * WAD);

        // Transfer 200,000,000 SKY to 0x483413ccCD796Deddee88E4d3e202425d5E891C6
        GemAbstract(SKY).transfer(FORTIFICATION_FOUNDATION, 200_000_000 * WAD);

        // ---------- Surplus Buffer Splitter parameter changes ----------
        // Forum: https://forum.sky.money/t/weekly-cycle-atlas-edit-proposal-week-starting-2025-08-11/27008
        // Poll: https://vote.sky.money/polling/Qmeba6D9

        // Decrease vow.hump by 49 million USDS, from 50 million to 1 million USDS
        DssExecLib.setSurplusBuffer(1_000_000);

        // Decrease splitter.burn by 25.00 percentage points, from 50% to 25%
        DssExecLib.setValue(MCD_SPLIT, "burn", WAD / 4); // Note: 100% == 1 WAD

        // ---------- UNIV2DAIUSDC-A Offboard ----------
        // Forum: https://forum.sky.money/t/univ2daiusdc-a-offboarding-proposal-august-21-spell/26949
        // Forum: https://forum.sky.money/t/univ2daiusdc-a-offboarding-proposal-august-21-spell/26949/2

        // Increase Local Liquidation Limit (hole) by 400k DAI, from 0 to 400k DAI
        DssExecLib.setIlkMaxLiquidationAmount("UNIV2DAIUSDC-A", 400_000);

        // Increase Liquidation Ratio by 898 percentage points, from 102% to 1,000%
        // Note: We are using low level methods because DssExecLib only allows setting `mat < 1000%`: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExecLib.sol#L717
        DssExecLib.setValue(MCD_SPOT, "UNIV2DAIUSDC-A", "mat", 10 * RAY);

        // Reduce Liquidation Penalty (chop) by 13 percentage points, from 13% to 0%
        DssExecLib.setIlkLiquidationPenalty("UNIV2DAIUSDC-A", 0);

        // Reduce Tip by 300, from 300 to 0
        DssExecLib.setKeeperIncentiveFlatRate("UNIV2DAIUSDC-A", 0);

        // Reduce Chip by 0.1 percentage points, from 0.1% to 0%
        DssExecLib.setKeeperIncentivePercent("UNIV2DAIUSDC-A", 0);

        // Update the value of stopped to 0 on MCD_CLIP_UNIV2DAIUSDC_A
        DssExecLib.setValue(MCD_CLIP_UNIV2DAIUSDC_A, "stopped", 0);

        // Note: Update collateral price to propagate the changes
        DssExecLib.updateCollateralPrice("UNIV2DAIUSDC-A");

        // ---------- Spark AAVE Revenue Share ----------
        // Forum: https://forum.sky.money/t/spark-aave-revenue-share-calculations-payments-8-q2-2025/27005
        // Forum: https://forum.sky.money/t/spark-aave-revenue-share-calculations-payments-8-q2-2025/27005/2

        // Transfer 177,507 USDS to 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c
        _transferUsds(AAVE_V3_TREASURY, 177_507 * WAD);

        // ---------- Liquidity Bootstrapping Funding ----------
        // Forum: https://forum.sky.money/t/utilization-of-the-sky-ecosystem-liquidity-bootstrapping-budget-a-5-6-1-9/25537/3
        // Atlas: https://sky-atlas.powerhouse.io/A.5.5.1.9_Sky_Ecosystem_Liquidity_Bootstrapping/109f2ff0-8d73-8029-baba-da835b70d03e%7C8d5aeb778e7c

        // Transfer 2 million USDS to 0xD8507ef0A59f37d15B5D7b630FA6EEa40CE4AFdD
        _transferUsds(LIQUIDITY_BOOTSTRAPPING, 2_000_000 * WAD);

        // ---------- Delegate Compensation for July 2025 ----------
        // Forum: https://forum.sky.money/t/july-2025-aligned-delegate-compensation/27015
        // Atlas: https://sky-atlas.powerhouse.io/Budget_And_Participation_Requirements/4c698938-1a11-4486-a568-e54fc6b0ce0c%7C0db3af4e

        // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // Excel - 4,000 USDS - 0x0F04a22B62A26e25A29Cba5a595623038ef7AcE7
        _transferUsds(EXCEL, 4_000 * WAD);

        // PBG - 4,000 USDS - 0x8D4df847dB7FfE0B46AF084fE031F7691C6478c2
        _transferUsds(PBG, 4_000 * WAD);

        // WBC - 3,871 USDS - 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47
        _transferUsds(WBC, 3_871 * WAD);

        // Tango - 731 USDS - 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 731 * WAD);

        // ---------- Atlas Core Development USDS Payments for August 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-august-2025/26976
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-august-2025/26976/7

        // BLUE - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // Kohla - 11,348 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a
        _transferUsds(CLOAKY_KOHLA_2, 11_348 * WAD);

        // ---------- Atlas Core Development SKY Payments for August 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-august-2025/26976
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-august-2025/26976/7

        // BLUE - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

        // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // ---------- Sky Frontier Foundation Grant ----------
        // Forum: https://forum.sky.money/t/weekly-cycle-atlas-edit-proposal-week-starting-2025-08-11/27008
        // Poll: https://vote.sky.money/polling/Qmeba6D9

        // Transfer 50,000,000 USDS to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        _transferUsds(SKY_FRONTIER_FOUNDATION, 50_000_000 * WAD);

        // Transfer all DAI held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(DAI).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(DAI).balanceOf(address(this)));

        // Transfer all UniV2 USDS-SKY LP (0x2621CC0B3F3c079c1Db0E80794AA24976F0b9e3c) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(UNIV2USDSSKY).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(UNIV2USDSSKY).balanceOf(address(this)));

        // Transfer all ENS (0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(ENS).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(ENS).balanceOf(address(this)));

        // Transfer all stkAAVE (0x4da27a545c0c5B758a6BA100e3a049001de870f5) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(STAAVE).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(STAAVE).balanceOf(address(this)));

        // Transfer all COMP (0xc00e94Cb662C3520282E6f5717214004A7f26888) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(COMP).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(COMP).balanceOf(address(this)));

        // Transfer all AAVE (0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(AAVE).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(AAVE).balanceOf(address(this)));

        // Transfer all WETH (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(ETH).transfer(SKY_FRONTIER_FOUNDATION, GemAbstract(ETH).balanceOf(address(this)));

        // Transfer all ETH held in the Pause Proxy to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        (bool success,) = payable(SKY_FRONTIER_FOUNDATION).call{ value: address(this).balance }("");
        // Note: call returns a boolean which needs to be checked
        require(success, "DssSpell/transfer-eth-failed");

        // Retain 16,000,000 SKY in the Pause Proxy and transfer the remaining SKY to 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        GemAbstract(SKY).transfer(
            SKY_FRONTIER_FOUNDATION,
            GemAbstract(SKY).balanceOf(address(this)) - 16_000_000 * WAD
        );

        // ---------- Execute Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/august-21-2025-proposed-changes-to-spark-for-upcoming-spell/26997
        // Poll: https://vote.sky.money/polling/QmNmGBSt
        // Poll: https://vote.sky.money/polling/QmefEkAi
        // Poll: https://vote.sky.money/polling/QmP8NVR5
        // Forum: https://forum.sky.money/t/spark-aave-revenue-share-calculations-payments-8-q2-2025/27005/2
        // Forum: https://forum.sky.money/t/august-21-2025-proposed-changes-to-spark-for-upcoming-spell-2/27059
        // Atlas: https://sky-atlas.powerhouse.io/A.2.9.1.2.2.5.4.1_Initial_Cash_Grant_To_Spark_Foundation/21ff2ff0-8d73-8018-be75-c28cee3dddb7%7C9e1f80092582d59891b0d93ee881
        // Poll: https://vote.sky.money/polling/QmenCpHX
        // Poll: https://vote.sky.money/polling/Qme2x6AU

        // Execute Spark proxy spell at 0xa57d3ea3aBAbD57Ed1a1d91CD998a68FB490B95E
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));

        // ---------- Execute Grove Proxy Spell ----------
        // Forum: https://forum.sky.money/t/august-21-2025-proposed-changes-to-grove-for-upcoming-spell/26993

        // Execute Grove proxy spell at 0xFa533FEd0F065dEf8dcFA6699Aa3d73337302BED
        ProxyLike(GROVE_PROXY).exec(GROVE_SPELL, abi.encodeWithSignature("execute()"));
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
