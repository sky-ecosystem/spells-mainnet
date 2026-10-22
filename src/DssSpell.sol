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

import { DssExec } from "dss-exec-lib/DssExec.sol";
import { DssAction, DssExecLib } from "dss-exec-lib/DssAction.sol";

interface BeamStateLike {
    function addInitRateLimits(bytes32 key, address rateLimits_, uint256 maxAmount, uint256 slope) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/c78666824c589ff021c85b4eb9d47fc0d2fe1172/2026/executive-vote-2026-10-22-init-osero-rate-limits.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-10-22 MakerDAO Executive Spell | Hash: 0x6eff7432d52c1fa6fbd6b83888beb3c56bf20116248ad347c8c2338ac5b262ba";

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
    address internal immutable PAS_STATE         = DssExecLib.getChangelogAddress("PAS_STATE");
    address internal immutable SPARK_STARGUARD   = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD   = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable PATTERN_STARGUARD = DssExecLib.getChangelogAddress("PATTERN_STARGUARD");

    // ---------- Osero ----------
    address internal constant OSERO_RATE_LIMITS  = 0xE9a78f34fe497e2186f81B8c014cd93B308BC62a;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL        = 0x78E4439ae74447992b111A73556a188229D34C37;
    bytes32 internal constant SPARK_SPELL_HASH   = 0x08c335ce1b2ad471186a566f08889631b3268cc74dc478b07e3c77f71c312166;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL        = 0xf9449D21ef687eE55233B9EDC3d7DDA87C7562a7;
    bytes32 internal constant GROVE_SPELL_HASH   = 0x7c9f6ed4604e78848e7b368736b8ae59f2209c6687977128a8302fafe1d6526c;

    // ---------- Pattern Spell ----------
    address internal constant PATTERN_SPELL      = 0xb38EB4a6f0Ae439a454EED67877f5aC7e66A7652;
    bytes32 internal constant PATTERN_SPELL_HASH = 0x2b3da408f1feea10a958fd5678dfe409d54500e8f1dfc2d0fe22c6b49b41b10c;

    function actions() public override {
        // ----- Add Initial Rate Limits for Osero -----
        // Forum: https://forum.skyeco.com/t/october-22-2026-proposed-changes-to-osero-for-upcoming-spell/28297
        // Atlas: https://sky-atlas.io/#cb293144-de0c-4bd8-9971-d96327b38ae9

        // Call PAS_STATE.addInitRateLimits(0xfc26a91cf7b79b531d45dcc431ee59e4f2504f51cb33e2b67960808a104c92ef, 0xE9a78f34fe497e2186f81B8c014cd93B308BC62a, 5000000000000, 7523148)
        BeamStateLike(PAS_STATE).addInitRateLimits({
            key: 0xfc26a91cf7b79b531d45dcc431ee59e4f2504f51cb33e2b67960808a104c92ef,
            rateLimits_: OSERO_RATE_LIMITS,
            maxAmount: 5_000_000_000_000, // Note: 5_000_000 USDC (6 decimals)
            slope: 7_523_148 // Note: 650_000 USDC (6 decimals) / 1 days (86_400 seconds)
        });

        // ----- Spark Proxy Spell -----
        // Forum: https://forum.skyeco.com/t/october-22-2026-proposed-changes-to-spark-for-upcoming-spell/28298
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x47341f1ff9453d3f3c6b088ebe1137c17a14536dde08aed2581019ca7ccef2f8
        // Poll: https://vote.sky.money/polling/QmQBiM5W
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Atlas: https://sky-atlas.io/#dfa483c7-5adb-480e-9f82-c97cf4d0f74e
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0x78E4439ae74447992b111A73556a188229D34C37 and codehash 0x08c335ce1b2ad471186a566f08889631b3268cc74dc478b07e3c77f71c312166 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ----- Grove Proxy Spell -----
        // Forum: https://forum.skyeco.com/t/october-22-2026-proposed-changes-to-grove-for-upcoming-spell/28296
        // Poll: https://vote.sky.money/polling/QmQBiM5W
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x7659f7a429ab635b7c41796c80f2f730008fe3dd2beb603f7ced05b7ac9cada8

        // Whitelist Grove spell with address 0xf9449D21ef687eE55233B9EDC3d7DDA87C7562a7 and codehash 0x7c9f6ed4604e78848e7b368736b8ae59f2209c6687977128a8302fafe1d6526c in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ----- Pattern Proxy Spell -----
        // Forum: https://forum.skyeco.com/t/technical-scope-for-the-october-22-2026-pattern-prime-spell/28295
        // Poll: https://vote.sky.money/polling/QmQBiM5W

        // Whitelist Pattern spell with address 0xb38EB4a6f0Ae439a454EED67877f5aC7e66A7652 and codehash 0x2b3da408f1feea10a958fd5678dfe409d54500e8f1dfc2d0fe22c6b49b41b10c in PATTERN_STARGUARD, direct execution: No
        StarGuardLike(PATTERN_STARGUARD).plot(PATTERN_SPELL, PATTERN_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
