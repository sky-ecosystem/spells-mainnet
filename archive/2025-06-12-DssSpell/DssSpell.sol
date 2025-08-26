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

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/dcbb94711df17f340365345435007f2a3aa208e2/2025/executive-vote-2025-06-12-housekeeping-spark-proxy-spell.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-06-12 MakerDAO Executive Spell | Hash: 0x9a536dc5d3f09ed4edfbd083bd421dbb456bdcf3fa2a43981f9533675a29284b";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return false;
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
    address internal immutable MCD_VAT = DssExecLib.vat();

    // ---------- Math ----------
    uint256 internal constant RAD = 10 ** 45;

    // ---------- Execute Spark Proxy Spell ----------
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0xF485e3351a4C3D7d1F89B1842Af625Fd0dFB90C8;

    function actions() public override {
        // ---------- Reduce BlockTower Andromeda (RWA015-A) Debt Ceiling and Remove from AutoLine ----------
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599/7

        // Note: Defining required variables for global debt ceiling reductions
        uint256 line;
        uint256 globalLineReduction = 0;

        // Note: Add currently set debt ceiling for RWA015-A to globalLineReduction
        (,,,line,) = VatAbstract(MCD_VAT).ilks("RWA015-A");
        globalLineReduction += line;

        // Remove RWA015-A from the AutoLine
        DssExecLib.removeIlkFromAutoLine("RWA015-A");

        // Set RWA015-A Debt Ceiling to 0 DAI
        DssExecLib.setIlkDebtCeiling("RWA015-A", 0);

        // Reduce Global Debt Ceiling to account for this change
        // Note: This is done collectively for all offboarded ilks below

        // ---------- Offboard BlockTower S3 (RWA012-A) ----------
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599/7

        // Note: Add currently set debt ceiling for RWA012-A to globalLineReduction
        (,,,line,) = VatAbstract(MCD_VAT).ilks("RWA012-A");
        globalLineReduction += line;

        // Set RWA012-A Debt Ceiling to 0 DAI
        DssExecLib.setIlkDebtCeiling("RWA012-A", 0);

        // Reduce Global Debt Ceiling to account for this change
        // Note: This is done collectively for all offboarded ilks below

        // ---------- Offboard BlockTower S4 (RWA013-A) ----------
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599
        // Forum: https://forum.sky.money/t/proposed-housekeeping-item-2025-06-12-executive/26599/7

        // Note: Add currently set debt ceiling for RWA013-A to globalLineReduction
        (,,,line,) = VatAbstract(MCD_VAT).ilks("RWA013-A");
        globalLineReduction += line;

        // Set RWA013-A Debt Ceiling to 0 DAI
        DssExecLib.setIlkDebtCeiling("RWA013-A", 0);

        // Reduce Global Debt Ceiling to account for this change
        // Note: This includes all offboarded ilks above as well
        DssExecLib.decreaseGlobalDebtCeiling(globalLineReduction / RAD);

        // ---------- Execute Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/june-12-2025-proposed-changes-to-spark-for-upcoming-spell/26559
        // Forum: https://forum.sky.money/t/june-12-2025-proposed-changes-to-spark-for-upcoming-spell/26559/3
        // Poll: https://vote.sky.money/polling/QmTX3KM9
        // Poll: https://vote.sky.money/polling/QmQRCn2K
        // Poll: https://vote.sky.money/polling/QmbY2bxz
        // Poll: https://vote.sky.money/polling/Qme3Des6
        // Poll: https://vote.sky.money/polling/QmUa7Au1
        // Poll: https://vote.sky.money/polling/QmSZJpsT
        // Poll: https://vote.sky.money/polling/QmRsqaaC
        // Poll: https://vote.sky.money/polling/QmdyVQok
        // Poll: https://vote.sky.money/polling/QmS3i2S3

        // Execute Spark Proxy Spell at address 0xF485e3351a4C3D7d1F89B1842Af625Fd0dFB90C8
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
