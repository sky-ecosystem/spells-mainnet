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
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";

interface BeamStateLike {
    function addCBeam(address cBeam) external;
    function addRateLimits(address rateLimits_) external;
    function setCBeamForRateLimits(address rateLimits_, address cBeam) external;
    function addController(address controller) external;
    function setCBeamForController(address controller, address cBeam) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/e4ab6f9e406c1526f49b9c33ab4de96f1b30166e/2026/executive-vote-2026-09-24-enable-osero-cbeam.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-09-24 MakerDAO Executive Spell | Hash: 0xf801b29d044f0ff6d67e57a7726ad742665f023a851b8ecc275d0aaec702ac27";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // Note: DAO resolution IPFS hashes, comma-separated when there is more than one
    string public constant dao_resolutions = "bafkreickfbtcslmburi6s4q6br6hn3j2cgdykf3ekv5i46r622vo3jzznm";

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

    // ---------- Contracts ----------
    address internal immutable MCD_IAM_AUTO_LINE = DssExecLib.autoLine();
    address internal immutable PAS_STATE         = DssExecLib.getChangelogAddress("PAS_STATE");
    address internal immutable SPARK_STARGUARD   = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD   = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable OSERO_STARGUARD   = DssExecLib.getChangelogAddress("OSERO_STARGUARD");

    // ---------- PAS ----------
    address internal constant OSERO_PAS_CBEAM   = 0x42D1038017E466b413aa44Ae798E30FB80b2E180;
    address internal constant OSERO_RATE_LIMITS = 0xE9a78f34fe497e2186f81B8c014cd93B308BC62a;
    address internal constant OSERO_CONTROLLER  = 0x24169Afb34fAe4D4356BC54Bd80319131e35ca38;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0xdE40689816DA168b0A56f8F22CBD7FfCFA403E6B;
    bytes32 internal constant SPARK_SPELL_HASH = 0xf5148b6a9fccbde7f225f4f098c28a112c065205a6bc321418154d41aa384bda;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0xFB1DEBB9CD8eD442103092C6aCd9ACC231224CFb;
    bytes32 internal constant GROVE_SPELL_HASH = 0x0106daf3bc397e10d8ee0b19996928b7a046d1f31bd31dba04c5cc2b2ea84fa6;

    // ---------- Osero Spell ----------
    address internal constant OSERO_SPELL      = 0xA061628c7f7bD95f571fd41f645746cC0d22f812;
    bytes32 internal constant OSERO_SPELL_HASH = 0x0c01396cee9cf147f0e4e5a715bf14326a81cd0e11c31d96c963d47bba52f4d8;

    function actions() public override {
        // ---------- Enable Osero cBEAM ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-oseros-cbeam-activation/28239
        // Poll: https://vote.sky.money/polling/QmeXvxdN

        // Call beamState.addCBeam with the following arguments
        BeamStateLike(PAS_STATE).addCBeam(
            // address cBeam: 0x42D1038017E466b413aa44Ae798E30FB80b2E180
            OSERO_PAS_CBEAM
        );

        // Call beamState.addRateLimits with the following arguments
        BeamStateLike(PAS_STATE).addRateLimits(
            // address rateLimits_: 0xE9a78f34fe497e2186f81B8c014cd93B308BC62a
            OSERO_RATE_LIMITS
        );

        // Call beamState.setCBeamForRateLimits with the following arguments
        BeamStateLike(PAS_STATE).setCBeamForRateLimits(
            // address rateLimits_: 0xE9a78f34fe497e2186f81B8c014cd93B308BC62a
            OSERO_RATE_LIMITS,
            // address cBeam: 0x42D1038017E466b413aa44Ae798E30FB80b2E180
            OSERO_PAS_CBEAM
        );

        // Call beamState.addController with the following arguments
        BeamStateLike(PAS_STATE).addController(
            // address controller: 0x24169Afb34fAe4D4356BC54Bd80319131e35ca38
            OSERO_CONTROLLER
        );

        // Call beamState.setCBeamForController with the following arguments
        BeamStateLike(PAS_STATE).setCBeamForController(
            // address controller: 0x24169Afb34fAe4D4356BC54Bd80319131e35ca38
            OSERO_CONTROLLER,
            // address cBeam: 0x42D1038017E466b413aa44Ae798E30FB80b2E180
            OSERO_PAS_CBEAM
        );

        // ---------- Adjust ALLOCATOR-GROVE-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229/9
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-GROVE-A",
            // Increase the Maximum Debt Ceiling (line) by 400,000,000 USDS from 100,000,000 USDS to 500,000,000 USDS
            _amount: 500 * MILLION,
            // Increase the Target Available Debt (gap) by 10,000,000 USDS from 15,000,000 USDS to 25,000,000 USDS
            _gap: 25 * MILLION,
            // Leave the Ceiling Increase Cooldown (ttl) unchanged at 43,200 seconds (12 hours)
            _ttl: 43_200 seconds
        });

        // Note: Apply the updated ALLOCATOR-GROVE-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-GROVE-A");

        // ---------- DAO Resolution for RWA009-A ----------
        // Forum: https://forum.skyeco.com/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/32
        // Forum: https://forum.skyeco.com/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/33

        // Approve DAO Resolution with hash bafkreickfbtcslmburi6s4q6br6hn3j2cgdykf3ekv5i46r622vo3jzznm
        // Note: see `dao_resolutions` public variable declared above

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-spark-for-upcoming-spell/28237
        // Atlas: https://sky-atlas.io/#1deecbd9-c3d8-45c4-a407-28386735833d
        // Atlas: https://sky-atlas.io/#dfa483c7-5adb-480e-9f82-c97cf4d0f74e
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0xdE40689816DA168b0A56f8F22CBD7FfCFA403E6B and codehash 0xf5148b6a9fccbde7f225f4f098c28a112c065205a6bc321418154d41aa384bda in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        // Atlas: https://sky-atlas.io/#bd2d15af-e32a-4ce9-a7ac-5a5ff1665fd4
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x014c93a287ea15d98148e0418f5262efa9a7c4c4ec8b8d3505cfac68674b3944
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x4713e4045e8780272aa56f483e54075566b2bdb66df8ed2c9beb6d5086bcbf73

        // Whitelist Grove spell with address 0xFB1DEBB9CD8eD442103092C6aCd9ACC231224CFb and codehash 0x0106daf3bc397e10d8ee0b19996928b7a046d1f31bd31dba04c5cc2b2ea84fa6 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-osero-for-upcoming-spell/28224
        // Poll: https://vote.sky.money/polling/Qmbk7ZFS

        // Whitelist Osero spell with address 0xA061628c7f7bD95f571fd41f645746cC0d22f812 and codehash 0x0c01396cee9cf147f0e4e5a715bf14326a81cd0e11c31d96c963d47bba52f4d8 in OSERO_STARGUARD, direct execution: No
        StarGuardLike(OSERO_STARGUARD).plot(OSERO_SPELL, OSERO_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
