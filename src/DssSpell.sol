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

    function actions() public override {
        // ---------- ALLOCATOR-GROVE-A Onboarding (TODO) ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-allocator-instance-for-grove/27966

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // sharedInstance.oracle being PIP_ALLOCATOR from chainlog
        // sharedInstance.roles being ALLOCATOR_ROLES from chainlog
        // sharedInstance.registry being ALLOCATOR_REGISTRY from chainlog
        // ilkInstance.owner being MCD_PAUSE_PROXY from chainlog
        // ilkInstance.vault being 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB
        // ilkInstance.buffer being 0x436DABce608f73BeA2b75fba35bffe72739697d5
        // cfg.ilk being ALLOCATOR-GROVE-A
        // cfg.duty being 0%
        // cfg.gap being TBD
        // cfg.maxLine being TBD
        // cfg.ttl being TBD
        // cfg.allocatorProxy being 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba
        // cfg.ilkRegistry being ILK_REGISTRY from chainlog
        // Remove the newly created PIP_ALLOCATOR_GROVE_A from chainlog
        // Add ALLOCATOR-GROVE-A ilk to the LINE_MOM
        // Add ALLOCATOR-GROVE-A ilk to the MCD_SPBEAM with the following parameters:
        // max being 3,000 basis points
        // min being 0 basis points
        // step being 400 basis points

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.16");

        // ---------- LitePSM Parameter Update ----------
        // Forum: https://forum.skyeco.com/t/lite-psm-usdc-a-parameter-change/27961
        // Forum: https://forum.skyeco.com/t/lite-psm-usdc-a-parameter-change/27961/2
        // Atlas: https://sky-atlas.io/#8694e11a-6acd-43f1-90fd-67eb7e7d98d6

        // Increase LITE-PSM-USDC-A `buf` by 400 million DAI from 400 million DAI to 800 million DAI
        // Increase LITE-PSM-USDC-A `gap` by 400 million DAI from 400 million DAI to 800 million DAI

        // ---------- stUSDS MOM Replacement ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967

        // Activate new STUSDS_MOM at 0x99159d0b885CC6633daC7CD4d82e4247A834b89A

        // ---------- Monthly Settlement Cycle for May 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-9-settlement-summary-may-2026/27962
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 13,427,874 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        // Send 4,204,857 USDS from the surplus buffer to the SPARK_SUBPROXY
        // Mint 8,877,823 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        // Send 271,843 USDS from the surplus buffer to the GROVE_SUBPROXY
        // Send 32,279 USDS from the surplus buffer to the KEEL_SUBPROXY
        // Mint 2,461,845 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        // Send 526,204 USDS from the surplus buffer to the OBEX_SUBPROXY
        // Send 1,806,616 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        // Transfer 2,946,125 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)

        // ---------- LSSKY-> SKY Rewards Normalization ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/24
        // Atlas: https://sky-atlas.io/#6cacdc1c-bdfa-4f68-bdb4-bf31943dcfba

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
        // vestTot: 240,862,942 SKY
        // vestBgn: block.timestamp
        // vestTau: 90 days

        // ---------- Safe Harbor Update (TODO) ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // TBD after technical scopes published

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/june-18-2026-proposed-changes-to-spark-for-upcoming-spell/27952
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xe556733096975218413695c0bd3905a865a38e4ded7603551b40f49cebfbb9ba
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x81e46a9c323dafde20fa6104fb93855889217b590335157c3c58be6760735747

        // Whitelist Spark spell with address 0xe08BD6D9016EAC522903FC68c80F809664C2692A and codehash 0xdf7cca8d640cde5f2f8184ccb03f76031a024cb8ab2c192092acfe329b5aebf5 in SPARK_STARGUARD, direct execution: No
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
