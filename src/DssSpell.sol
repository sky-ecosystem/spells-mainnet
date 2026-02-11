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

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/25e93301d88ab5061e95c3f907d628ec03641caf/2026/executive-vote-2026-02-12-adjust-nova-dciam-parameters-reduce-6s-stability-fee.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-02-12 MakerDAO Executive Spell | Hash: 0x1ff27b0b4d972710e793b0922f2c06e613ea4f0efadd993c0fef0c87ec069518";

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
    uint256 internal constant ZERO_PCT_RATE = 1000000000000000000000000000;

    // ---------- Math ----------
    uint256 internal constant RAD = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT         = DssExecLib.vat();
    address internal immutable SPARK_STARGUARD = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0x42dB2A32C5F99034C90DaC07BF790f738b127e93;
    bytes32 internal constant SPARK_SPELL_HASH = 0x1921fcf54407302328fe5dfa4b48ab0802a5607edcfdace144e62e27f26ffff5;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0xe045AA2065FDba35a0e0B5283e7f36a8ca96886a;
    bytes32 internal constant GROVE_SPELL_HASH = 0x5fd619a8b7922b59d639fc5b47f736e8590cf174ac070f2943bef4266304ffeb;

    function actions() public override {
        // ---------- Adjust ALLOCATOR-NOVA-A Ilk Parameters ----------
        // Forum: https://forum.sky.money/t/allocator-nova-a-parameter-changes/27692
        // Atlas: https://sky-atlas.io/#A.3.7.1.2.2

        // Remove ALLOCATOR-NOVA-A ilk from AutoLine
        DssExecLib.removeIlkFromAutoLine("ALLOCATOR-NOVA-A");

        // Note: in order to decrease global debt ceiling, we need to fetch current `line`
        (,,, uint256 line,) = VatAbstract(MCD_VAT).ilks("ALLOCATOR-NOVA-A");

        // Set ALLOCATOR-NOVA-A ilk Debt Ceiling to 0
        DssExecLib.setIlkDebtCeiling("ALLOCATOR-NOVA-A", 0);

        // Reduce Global Debt Ceiling to account for this change
        DssExecLib.decreaseGlobalDebtCeiling(line / RAD);

        // ---------- Adjust RWA001-A Stability Fee ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-rwa001-a-offboarding/27706
        // Forum: https://forum.sky.money/t/technical-scope-of-rwa001-a-offboarding/27706/2

        // Set the RWA001-A Stability Fee to 0%
        DssExecLib.setIlkStabilityFee("RWA001-A", ZERO_PCT_RATE, /* doDrip = */ true);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-12-2026-proposed-changes-to-spark-for-upcoming-spell/27674
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x444abfce22102793c25d85d659ff69747fdc56091e41dd6e7c67a9ac5d1b1b15
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x3ffd7702f9f23b9dabbb6297e6690f9f648e9968fc88fbfc4fe3aee41d764569

        // Whitelist Spark spell with address 0x42dB2A32C5F99034C90DaC07BF790f738b127e93 and codehash 0x1921fcf54407302328fe5dfa4b48ab0802a5607edcfdace144e62e27f26ffff5 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-12-2026-proposed-changes-to-grove-for-upcoming-spell/27662
        // Poll: https://vote.sky.money/polling/QmPUQMm9

        // Whitelist Grove spell with address 0xe045AA2065FDba35a0e0B5283e7f36a8ca96886a and codehash 0x5fd619a8b7922b59d639fc5b47f736e8590cf174ac070f2943bef4266304ffeb in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
