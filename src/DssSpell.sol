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

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-11-19 MakerDAO Executive Spell | Hash: TODO";

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
        // ---------- Monthly Settlement Cycle for October 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-14-settlement-summary-october-2026/28406
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 14,048,690 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.

        // Send 4,188,099 USDS from the surplus buffer to the SPARK_SUBPROXY

        // Mint 8,866,792 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.

        // Send 2,170,826 USDS from the surplus buffer to the GROVE_SUBPROXY

        // Send 34,034 USDS from the surplus buffer to the KEEL_SUBPROXY

        // Mint 1,463,217 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.

        // Send 205,907 USDS from the surplus buffer to the OBEX_SUBPROXY

        // Send 145,439 USDS from the surplus buffer to the SKYBASE_SUBPROXY

        // Mint 15,812 USDS debt in ALLOCATOR-PRYSM-A and transfer the amount to the surplus buffer.

        // Send 42,396 USDS from the surplus buffer to the OSERO_SUBPROXY

        // Send 1,000,000 USDS from the surplus buffer to the Demand Side Buffer at 0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B

        // ---------- Treasury Management Function ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/10
        // Atlas: https://sky-atlas.io/#f67a5780-11d5-4014-8254-795080c77133

        // Send 3,720,082 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)

        // Burn 7,770,211 SKY tokens from the PauseProxy Balance

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
        // vestTot: 104,897,852 SKY
        // vestBgn: block.timestamp
        // vestTau: 90 days

        // Decrease splitter.hop by 574 seconds from 2,693 seconds to 2,119 seconds

        // Decrease rewardsDuration in REWARDS_LSSKY_USDS by 574 seconds from 2,693 seconds to 2,119 seconds

        // ---------- Adjust Core Vault DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/core-vaults-parameter-changes-set-dc-iam-line-to-0-on-eth-a-eth-b-eth-c-wsteth-a-and-wsteth-b/28399

        // Remove ETH-A from autoline

        // Set ETH-A Debt Ceiling to 0

        // Remove ETH-B from autoline

        // Set ETH-B Debt Ceiling to 0

        // Remove ETH-C from autoline

        // Set ETH-C Debt Ceiling to 0

        // Remove WSTETH-A from autoline

        // Set WSTETH-A Debt Ceiling to 0

        // Remove WSTETH-B from autoline

        // Set WSTETH-B Debt Ceiling to 0

        // Note: reduce the global debt ceiling by the sum of the five pre-change ilk debt ceilings.
        // TODO

        // ---------- Finalize Legacy USDC PSM Offboarding ----------
        // Forum: https://forum.skyeco.com/t/psm-usdc-a-housekeeping/28417
        // Atlas: https://sky-atlas.io/#0d0e2e1a-0502-4ee3-bc9d-8bd8ddde19ec

        // Finalize Offboarding of the Legacy USDC PSM

        // Send rescued USDC to the CC Buffer at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364

        // ---------- Initialize Test Halo SubProxy and StarGuard ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-for-the-new-test-halo-agent-setup/28418
        // Poll: https://vote.sky.money/polling/QmPNbnSS

        // Call StarGuardInit.init with chainlog = DssExecLib.LOG, cfg.subProxy = 0xF12Be1673758f8fBC275755401774Ec45C80c0F0, cfg.subProxyKey = TEST_HALO_SUBPROXY, cfg.starGuard = 0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056, cfg.starGuardKey = TEST_HALO_STARGUARD, and cfg.maxDelay = 7 days.

        // Call CRON_STARGUARD_JOB.add(0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056).

        // Note: bump Chainlog version
        // TODO

        // ---------- [Base] Configure the Beacon and PAS for Osero’s DPAU Launch ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-core-l2-spell-on-base-assisting-osero-s-dpau-launch/28413
        // Atlas: https://sky-atlas.io/#24c2fc14-448d-48be-a416-86bfad6f33fe

        // Call L2_PAU_BEACON.setIntegration for bytes32("ERC4626_FACET") with facet = 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D and wires copied from Ethereum mainnet PAU_BEACON.getConfig(bytes32("ERC4626_FACET")).wires.

        // Call L2_PAS_STATE.addCBeam(0x42D1038017E466b413aa44Ae798E30FB80b2E180).

        // Call L2_PAS_STATE.addRateLimits(0xd9E629588c48722E4c1bfcfb17829FecAf73839f).

        // Call L2_PAS_STATE.setCBeamForRateLimits(0xd9E629588c48722E4c1bfcfb17829FecAf73839f, 0x42D1038017E466b413aa44Ae798E30FB80b2E180).

        // Call L2_PAS_STATE.addController(0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9).

        // Call L2_PAS_STATE.setCBeamForController(0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9, 0x42D1038017E466b413aa44Ae798E30FB80b2E180).

        // From the Ethereum Core spell, call BASE_GOV_RELAY.relay targeting 0x682048513247076Fb5dB4762121BdB136182e4A9. Encode L2MulticallSpell.execute with the six Base calls above in order and deadline = block.timestamp + 7 days at the Ethereum cast. Set minGasLimit = 1_000_000.

        // ---------- Update Safe Harbor Agreement ----------

        // Note: code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        /*
        bytes[] memory calldatas = new bytes[](2);

        // Add accounts to eip155:1 chain: 0xF12Be1673758f8fBC275755401774Ec45C80c0F0, 0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078463132426531363733373538663866424332373537353534303137373445633435433830633046300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783564633741333730304463303530386635453132374641323361636438336363324531443630353600000000000000000000000000000000000000000000';

        // Add accounts to eip155:8453 chain: 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D, 0x682048513247076Fb5dB4762121BdB136182e4A9
        calldatas[1] = hex'46c2b73400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b6569703135353a383435330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078433646623534333438666543646232373930466139313330443166633335643645313031433937440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783638323034383531333234373037364662356442343736323132314264423133363138326534413900000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);
        */

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-spark-for-upcoming-spell/28390
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x5547b7f06c852c98c517e53fb8f2516062d7d890c9abd1bd7b2c9a5db67f9289
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://vote.sky.money/polling/QmYWJPcE
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf1426e0ea2fcab571a5d59e650b24a88f56c041efe8ddc31d22a9d354dd57f97
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x38093a3ead044a60511d1451ae04d0768e65b4ac32e19069c4d78335b64df61d
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x61efe7dcaadc2baf6b0dde519ceb3e360f7ac864c888004108d97012843246ed
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x4ca8fbf47c4679aa74d3cd6681c89ced9383e9f923b7dc6f33c94f7f8f0cee5b
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x807d260ba5b828e4e886727c66b4bb5666a76a8dcf78cff89bb2584f7580ea17

        // Whitelist Spark spell with address TBD and codehash TBD in SPARK_STARGUARD, direct execution: TBD

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-grove-for-upcoming-spell/28387
        // Poll: https://vote.sky.money/polling/QmYWJPcE
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x6a024ffdd779c80702e6c11dd8343a64627e7bfe5cfe4f33b1a4fa6cd3f3a5cf
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x6b470d2a31a6e1723376a35691a551c521739d85f9f55672793857405cab88a5
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x319e9c02e0cbd1a4c9e1647fdb5b2c7ad99bc7076b3a7cd5f49c58d8a1d7cdef

        // Whitelist Grove spell with address 0x1a74cC68A37f24367914fAc1915cC604CB3D72AF and codehash 0x45f2833db32128803bd3ce7dc8fa9837a38db7791cacd99ac1c90598d0a70bc9  in GROVE_STARGUARD, direct execution: No

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-osero-for-upcoming-spell/28388
        // Poll: https://vote.sky.money/polling/QmYWJPcE

        // Whitelist Osero spell with address 0xC1989b5c81eA2bC4A6Abda0e73e3E3C48D500d05 and codehash 0xd99ef190c8ebdfbe3ddd67e84a2d63243b0f354e4841928a8bc6869a4055d77b in OSERO_STARGUARD, direct execution: No
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
