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
    string public constant override description = "2026-02-26 MakerDAO Executive Spell | Hash: TODO";

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

    function actions() public override {
        // ---------- Launch Agent 6 Onboarding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-launch-agent-6-allocator-instance/27724
        // Poll: https://vote.sky.money/polling/QmQ95c8b

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // sharedInstance.oracle: PIP_ALLOCATOR from chainlog
        // sharedInstance.roles: ALLOCATOR_ROLES from chainlog
        // sharedInstance: ALLOCATOR_REGISTRY from chainlog
        // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog
        // ilkInstance.vault: 0x146181Aa9B362EaEC2eC3aDd7429a06D53B43d1a (AllocatorVault contract)
        // ilkInstance.buffer: 0xD0BB61b34771146e31055f20f329cDf97429F889 (AllocatorBuffer contract)
        // cfg.ilk: ALLOCATOR-PRYSM-A
        // cfg.duty: 0
        // cfg.gap: 10 million
        // cfg.maxLine: 10 million
        // cfg.ttl: 86,400 seconds
        // cfg.AllocatorProxy: 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3
        // cfg.ilkRegistry: ILK_REGISTRY from chainlog

        // Remove newly created PIP_ALLOCATOR_PRYSM_A from chainlog

        // Add ALLOCATOR-PRYSM-A ilk to the LINE_MOM

        // Add ALLOCATOR-PRYSM-A ilk to the SP-BEAM with the following parameters:
        // max: 3,000 bps
        // min: 0 bps
        // step: 400 bps

        // Init new StarGuard module by calling StarGuardInit.init with:
        // chainlog: DssExecLib.LOG
        // cfg.subProxy: 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3
        // cfg.subProxyKey: "PRYSM_SUBPROXY"
        // cfg.starGuard: 0xBfA2D1dA838E55A74c61699e164cDFF8cF0cF0e2
        // cfg.starGuardKey: "PRYSM_STARGUARD"
        // cfg.maxDelay: 7 days
        // Add PRYSM_STARGUARD module to the StarGuardJob

        // ---------- Launch Agent 7 Onboarding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-launch-agent-7-allocator-instance/27725
        // Poll: https://vote.sky.money/polling/QmcxUENd

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // sharedInstance.oracle: PIP_ALLOCATOR from chainlog
        // sharedInstance.roles: ALLOCATOR_ROLES from chainlog
        // sharedInstance: ALLOCATOR_REGISTRY from chainlog
        // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog
        // ilkInstance.vault: 0xDD3bE7650589E6A6171d454b026C4AD1a2C02720 (AllocatorVault contract)
        // ilkInstance.buffer: 0x67Ac5c8FbFDAc5265c995e9B2ACd830496438AfD (AllocatorBuffer contract)
        // cfg.ilk: ALLOCATOR-INTERVAL-A
        // cfg.duty: 0
        // cfg.gap: 10 million
        // cfg.maxLine: 10 million
        // cfg.ttl: 86,400 seconds
        // cfg.AllocatorProxy: 0x56a9bA5FE133EF4Ab1131E8ac7c4312a52284f5B
        // cfg.ilkRegistry: ILK_REGISTRY from chainlog

        // Remove newly created PIP_ALLOCATOR_INTERVAL_A from chainlog

        // Add ALLOCATOR-INTERVAL-A ilk to the LINE_MOM

        // Add ALLOCATOR-INTERVAL-A ilk to the SP-BEAM with the following parameters:
        // max: 3,000 bps
        // min: 0 bps
        // step: 400 bps

        // Init new StarGuard module by calling StarGuardInit.init with:
        // chainlog: DssExecLib.LOG
        // cfg.subProxy: 0x56a9bA5FE133EF4Ab1131E8ac7c4312a52284f5B
        // cfg.subProxyKey: "INTERVAL_SUBPROXY"
        // cfg.starGuard: 0xB36e88c02E4619Ef34C0Db76C5BCb6655747FB28
        // cfg.starGuardKey: "INTERVAL_STARGUARD"
        // cfg.maxDelay: 7 days
        // Add INTERVAL_STARGUARD module to the StarGuardJob

        // ---------- January 2026 MSC ----------
        // Forum: https://forum.sky.money/t/msc-5-settlement-summary-january-2026-spark-and-grove/27709/4
        // Atlas: https://sky-atlas.io/#A.2.4

        // Mint 8,079,210 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer

        // Send 1,387,824 USDS from the Surplus Buffer to the SPARK_SUBPROXY

        // Mint 6,205,320 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer

        // Send 6,090 USDS from the Surplus Buffer to the GROVE_SUBPROXY

        // Mint 2,095,775 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the Surplus Buffer

        // Send 71,342 USDS from the surplus buffer to the OBEX_SUBPROXY

        // Transfer 4,808,248 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)

        // Transfer 240,412 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3)

        // ---------- LSSKY->SKY Vesting Stream Adjustment ----------
        // Forum: https://forum.sky.money/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/2
        // Atlas: https://sky-atlas.io/#A.4.4.1.4.2.1.3.3
        // Forum: https://forum.sky.money/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/3

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_LSSKY_SKY

        // MCD_VEST_SKY_TREASURY Vest Stream  | from: 'block.timestamp' | tau: 180 days | tot: 838,182,330 SKY | usr: REWARDS_DIST_LSSKY_SKY
        // res: 1 (restricted)

        // Adjust the Sky allowance for MCD_VEST_SKY_TREASURY, reducing it by the remaining yanked stream amount and increasing it by the new stream total

        // Yank MCD_VEST_SKY_TREASURY vest with ID 8

        // File the new stream ID on REWARDS_DIST_LSSKY_SKY

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-26-2026-proposed-changes-to-spark-for-upcoming-spell/27719
        // Atlas: https://sky-atlas.io/#A.2.8.2.2.2.5.5.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.4.2.3.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xdc1931c6f37149183ae2f15b61f56621d5091d1ce4469ad95cc6cdd33963db8c
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xf1a95e7ddaf2f95008608d7e27d8bed9ba6e9c7c55060e8e595f414d88e6b5c9
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x29be63afc3b7495581259401c68e6dd892e0a8870a45ad66b2d7b224f4b33dde

        // Whitelist Spark spell with address 0xf655F6E7843685BfD8cfA4523d43F2b9922BBd77 and codehash 0x56ca6d051fe05ba6a2b3f054aad61ce93e69542faf2ad02b9881bc1c03c8d2bf in SPARK_STARGUARD, direct execution: No

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-26-2026-proposed-changes-to-grove-for-upcoming-spell/27712
        // Poll: https://vote.sky.money/polling/QmcxUENd
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
