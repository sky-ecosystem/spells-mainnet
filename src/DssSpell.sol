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

import { VatAbstract }         from "dss-interfaces/dss/VatAbstract.sol";
import { IlkRegistryAbstract } from "dss-interfaces/dss/IlkRegistryAbstract.sol";

interface ChainlogLike {
    function removeAddress(bytes32) external;
}

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/637e2eee88d66b1430da42910721bdae50b756bd/2025/executive-vote-2025-07-24.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-07-08 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 constant internal RAD = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT      = DssExecLib.vat();
    address internal immutable ILK_REGISTRY = DssExecLib.reg();
    address internal immutable CHAINLOG     = DssExecLib.LOG;

    // ---------- Grove Proxy Spell ----------
    // Note: The deployment address for the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant GROVE_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;
    address internal constant GROVE_SPELL = 0xa25127f759B6F07020bf2206D31bEb6Ed04D1550;

    // ---------- Spark Proxy Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0xb12057500EB57C3c43B91171D52b6DB141cCa01a;

    function actions() public override {
        // ----- Deactivate Legacy Morpho DAI Vault DDM -----
        // Forum: https://forum.sky.money/t/august-7-2025-proposed-changes-to-spark-for-upcoming-spell/26896
        // Poll: https://vote.sky.money/polling/QmeLZrZo

        // Note: Get the debt ceiling for DIRECT-SPARK-MORPHO-DAI
        (,,,uint256 line,) = VatAbstract(MCD_VAT).ilks("DIRECT-SPARK-MORPHO-DAI");

        // Remove DIRECT-SPARK-MORPHO-DAI from the Autoline
        DssExecLib.removeIlkFromAutoLine("DIRECT-SPARK-MORPHO-DAI");

        // Set DIRECT-SPARK-MORPHO-DAI Debt Ceiling to 0
        DssExecLib.setIlkDebtCeiling("DIRECT-SPARK-MORPHO-DAI", 0);

        // Reduce Global Debt Ceiling to account for this change
        DssExecLib.decreaseGlobalDebtCeiling(line / RAD);

        // ----- Retire Legacy MKR Oracle -----
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-item-housekeeping-august-7th-spell/26919/3

        // Remove PIP_MKR from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_MKR");

        // Remove LSE-MKR-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("LSE-MKR-A");

        // ----- [Housekeeping] Retire Other Legacy Oracles -----
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-item-housekeeping-august-7th-spell/26919/3

        // Remove PIP_AAVE from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_AAVE");

        // Remove PIP_ADAI from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_ADAI");

        // Remove PIP_BAL from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_BAL");

        // Remove PIP_BAT from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_BAT");

        // Remove PIP_COMP from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_COMP");

        // Remove PIP_CRVV1ETHSTETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_CRVV1ETHSTETH");

        // Remove PIP_GNO from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_GNO");

        // Remove PIP_GUSD from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_GUSD");

        // Remove PIP_KNC from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_KNC");

        // Remove PIP_LINK from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_LINK");

        // Remove PIP_LRC from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_LRC");

        // Remove PIP_MANA from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_MANA");

        // Remove PIP_MATIC from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_MATIC");

        // Remove PIP_PAX from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_PAX");

        // Remove PIP_PAXUSD from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_PAXUSD");

        // Remove PIP_RENBTC from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RENBTC");

        // Remove PIP_RETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RETH");

        // Remove PIP_RWA003 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA003");

        // Remove PIP_RWA006 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA006");

        // Remove PIP_RWA007 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA007");

        // Remove PIP_RWA008 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA008");

        // Remove PIP_RWA010 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA010");

        // Remove PIP_RWA011 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA011");

        // Remove PIP_RWA012 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA012");

        // Remove PIP_RWA013 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA013");

        // Remove PIP_RWA014 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA014");

        // Remove PIP_RWA015 from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_RWA015");

        // Remove PIP_TUSD from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_TUSD");

        // Remove PIP_UNI from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNI");

        // Remove PIP_UNIV2AAVEETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2AAVEETH");

        // Remove PIP_UNIV2DAIETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2DAIETH");

        // Remove PIP_UNIV2DAIUSDT from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2DAIUSDT");

        // Remove PIP_UNIV2ETHUSDT from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2ETHUSDT");

        // Remove PIP_UNIV2LINKETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2LINKETH");

        // Remove PIP_UNIV2UNIETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2UNIETH");

        // Remove PIP_UNIV2USDCETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2USDCETH");

        // Remove PIP_UNIV2WBTCDAI from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2WBTCDAI");

        // Remove PIP_UNIV2WBTCETH from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_UNIV2WBTCETH");

        // Remove PIP_USDC from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_USDC");

        // Remove PIP_USDT from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_USDT");

        // Remove PIP_YFI from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_YFI");

        // Remove PIP_ZRX from the Chainlog
        ChainlogLike(CHAINLOG).removeAddress("PIP_ZRX");

        // ----- Remove Offboarded ilks from the Ilk Registry -----
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-item-housekeeping-august-7th-spell/26919/3

        // Remove AAVE-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("AAVE-A");

        // Remove ADAI-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("ADAI-A");

        // Remove BAL-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("BAL-A");

        // Remove BAT-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("BAT-A");

        // Remove COMP-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("COMP-A");

        // Remove CRVV1ETHSTETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("CRVV1ETHSTETH-A");

        // Remove GNO-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("GNO-A");

        // Remove GUSD-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("GUSD-A");

        // Remove KNC-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("KNC-A");

        // Remove LINK-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("LINK-A");

        // Remove LRC-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("LRC-A");

        // Remove LSE-MKR-A from the ilk registry
        // Note: Removed above

        // Remove MANA-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("MANA-A");

        // Remove MATIC-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("MATIC-A");

        // Remove PAX-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("PAX-A");

        // Remove PAXUSD-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("PAXUSD-A");

        // Remove RENBTC-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RENBTC-A");

        // Remove RETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RETH-A");

        // Remove RWA003-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA003-A");

        // Remove RWA006-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA006-A");

        // Remove RWA007-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA007-A");

        // Remove RWA008-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA008-A");

        // Remove RWA010-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA010-A");

        // Remove RWA011-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA011-A");

        // Remove RWA012-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA012-A");

        // Remove RWA013-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA013-A");

        // Remove RWA014-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA014-A");

        // Remove RWA015-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("RWA015-A");

        // Remove TUSD-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("TUSD-A");

        // Remove UNI-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNI-A");

        // Remove UNIV2AAVEETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2AAVEETH-A");

        // Remove UNIV2DAIETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2DAIETH-A");

        // Remove UNIV2DAIUSDT-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2DAIUSDT-A");

        // Remove UNIV2ETHUSDT-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2ETHUSDT-A");

        // Remove UNIV2LINKETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2LINKETH-A");

        // Remove UNIV2UNIETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2UNIETH-A");

        // Remove UNIV2USDCETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2USDCETH-A");

        // Remove UNIV2WBTCDAI-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2WBTCDAI-A");

        // Remove UNIV2WBTCETH-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("UNIV2WBTCETH-A");

        // Remove USDC-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("USDC-A");

        // Remove USDC-B from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("USDC-B");

        // Remove USDT-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("USDT-A");

        // Remove YFI-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("YFI-A");

        // Remove ZRX-A from the ilk registry
        IlkRegistryAbstract(ILK_REGISTRY).remove("ZRX-A");

        // Note: Bump Chainlog version to ...

        // ----- Execute Spark Proxy Spell -----
        // Forum: https://forum.sky.money/t/august-7-2025-proposed-changes-to-spark-for-upcoming-spell/26896
        // Poll: https://vote.sky.money/polling/QmXLExe7
        // Poll: https://vote.sky.money/polling/QmVGr47c
        // Poll: https://vote.sky.money/polling/QmUevv3W
        // Poll: https://vote.sky.money/polling/QmU6L1gS
        // Poll: https://vote.sky.money/polling/QmZu3tVL

        // Execute Spark proxy spell at 0xb12057500EB57C3c43B91171D52b6DB141cCa01a
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));

        // ----- Execute Grove Proxy Spell -----
        // Forum: https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll: https://vote.sky.money/polling/QmX2CAp2
        // Poll: https://vote.sky.money/polling/QmNsimEt

        // Execute Grove proxy spell at 0xa25127f759B6F07020bf2206D31bEb6Ed04D1550
        ProxyLike(GROVE_PROXY).exec(GROVE_SPELL, abi.encodeWithSignature("execute()"));
    }

}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
