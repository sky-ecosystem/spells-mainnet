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

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-01-29 MakerDAO Executive Spell | Hash: TODO";

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

    function actions() public override {
    // ---------- Monthly Settlement Cycle and Treasury Management Function for November and December ----------
    // Forum: https://forum.sky.money/t/msc-4-settlement-summary-november-and-december-2025-spark-grove/27617/5
    // Atlas: https://sky-atlas.io/#A.2.4
    // Atlas: https://sky-atlas.io/#A.2.3.1.4.1.1
    // Atlas: https://sky-atlas.io/#A.2.3.1.4.1.2

    // Mint 25,547,255 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer

    // Transfer 7,071,339 USDS from the surplus buffer to the SPARK_SUBPROXY

    // Mint 14,311,822 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer

    // Mint 1,768,819 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the Surplus Buffer.

    // Transfer 442,327 USDS from the Surplus Buffer to the OBEX_SUBPROXY

    // Transfer 6,632,421 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364).

    // Transfer 331,620 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3).

    // ---------- Pattern Onboarding ----------
    // Forum: https://forum.sky.money/t/technical-scope-of-the-new-pattern-allocator-instance/27641

    // Init new Allocator instance by calling AllocatorInit.initIlk with:

    // sharedInstance.oracle: PIP_ALLOCATOR from chainlog

    // sharedInstance.roles: ALLOCATOR_ROLES from chainlog

    // sharedInstance: ALLOCATOR_REGISTRY from chainlog

    // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog

    // ilkInstance.vault: 0xbd34fc6AAa1d3F52B314CB9D78023dd23eAc3B0E

    // ilkInstance.buffer: 0x823459b55D79F0421f24a4828237F7ecb8D7F1ef

    // cfg.ilk: ALLOCATOR-PATTERN-A

    // cfg.duty: 0

    // cfg.gap: 10 million USDS

    // cfg.maxLine: 10 million USDS

    // cfg.ttl: 86,400 seconds

    // cfg.AllocatorProxy: 0xbC8959Ae2d4E9B385Fe620BEF48C2FD7f4A84736

    // cfg.ilkRegistry: ILK_REGISTRY from chainlog

    // Remove newly created PIP_ALLOCATOR_PATTERN_A from chainlog

    // Add ALLOCATOR-PATTERN-A ilk to the LINE_MOM

    // Add ALLOCATOR-PATTERN-A ilk to the SP-BEAM with the following parameters:

    // max: 3,000 bps

    // min: 0 bps

    // step: 400 bps

    // Init new StarGuard module by calling StarGuardInit.init with:

    // chainlog: DssExecLib.LOG

    // cfg.subProxy: 0xbC8959Ae2d4E9B385Fe620BEF48C2FD7f4A84736

    // cfg.subProxyKey: PATTERN_SUBPROXY

    // cfg.starGuard: 0x2fb18b28fB39Ec3b26C3B5AF5222e2ca3B8B2269

    // cfg.starGuardKey: PATTERN_STARGUARD

    // cfg.maxDelay: 7 days

    // Add PATTERN_STARGUARD module to the StarGuardJob

    // ---------- Skybase Onboarding and Genesis Capital Funding ----------
    // Forum: https://forum.sky.money/t/technical-scope-of-the-new-skybase-agent/27642
    // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-19/27627
    // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-19/27627/3
    // Atlas: https://sky-atlas.io/#A.2.8.2.7.2.2

    // Initialize new StarGuard module by calling StarGuardInit.init with:

    // chainlog: DssExecLib.LOG

    // cfg.subProxy: 0x08978E3700859E476201c1D7438B3427e3C81140

    // cfg.subProxyKey: SKYBASE_SUBPROXY

    // cfg.StarGuard: 0xA170086AeF9b3b81dD73897A0dF56B55e4C2a1F7

    // cfg.starGuardKey: SKYBASE_STARGUARD

    // cfg.maxDelay: 7 days

    // Add SKYBASE_STARGUARD to the StarGuardJob

    // Transfer 10 million USDS to SKYBASE_SUBPROXY

    // Transfer 5 million USDS to the USDS Demand Subsidies Multisig at 0x3F32bC09d41eE699844F8296e806417D6bf61Bba

    // ---------- DAO Resolution for RWA001-A ----------
    // Forum: https://forum.sky.money/t/rwa-001-6s-capital-update-and-stability-fee-proposal/24624/4
    // Forum: https://forum.sky.money/t/rwa-001-6s-capital-update-and-stability-fee-proposal/24624/5

    // Approve DAO Resolution with hash bafkreiczdjq55zsxvxcf4le3oaqvhp4jgvls4n4b7xbnzvkwilzen3a2te

    // ---------- Spark Proxy Spell ----------
    // Forum: https://forum.sky.money/t/january-29-2026-proposed-changes/27620
    // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.2.1.2.1
    // Atlas: https://sky-atlas.io/#A.2.8.2.2.2.5.5.2
    // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x7888032804772315db4be8e2d0c59ec50c70fbc0d4e7c5bab0af0a4b7391070e
    // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x64bd800579115f0a11a1290af898bdbe587947cd483afab3998b8454e3a4fb2d
    // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xa1b2e3a136cca3a6df5498a074aeecad8bee871866726b7568b19c087ff33178

    // Whitelist Spark spell with address 0xa091BeD493C27efaa4D6e06e32684eCa0325adcA and codehash 0x6ef4bf2258afab1e1c857892e5253e95880230a86ee9adc773fab559d7a594ec in SPARK_STARGUARD, direct execution: No

    // ---------- Grove Proxy Spell ----------
    // Forum: https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608

    // Whitelist Grove spell with address 0x67aB5b15E3907E3631a303c50060c2207465a9AD and codehash 0x7e4eb1e46f50b347fc7c8d20face6070c8fda4876049e32f3877a89cede1d533 in GROVE_STARGUARD, direct execution: No

    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
