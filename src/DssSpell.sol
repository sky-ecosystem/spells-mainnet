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
    string public constant override description = "2025-10-16 MakerDAO Executive Spell | Hash: TODO";

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
        // ---------- Lssky-SKY Farm Initialization ----------

        // ---------- Obex Allocator Initialization ----------

        // ---------- Monthly Settlement Cycle #2 ----------
        // Forum: https://forum.sky.money/t/msc-2-settlement-summary-september-2025-spark-only-initial-calculations/27286/2
        // Atlas: https://sky-atlas.powerhouse.io/A.2.5.1.2.2.1_Stage_1/241f2ff0-8d73-8014-b124-e76f5f5c91fc%7C9e1fcc279923ea16fa2d

        // Spark

        // Mint 16,931,086 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer

        // Send 3,827,201 USDS to 0x3300f198988e4C9C63F75dF86De36421f06af8c4 (Spark SubProxy)

        // Bloom/Grove

        // Mint 6,382,973 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer

        // Send 104,924 USDS to 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba (Grove SubProxy)

        // ---------- Ranked Delegate Compensation ----------
        // Forum: https://forum.sky.money/t/september-2025-ranked-delegate-compensation/27305
        // Atlas: https://sky-atlas.powerhouse.io/A.1.5.6.1_Budget_Amount_For_Ranked_Delegate_Slots/a8a767c3-9594-4e84-aa14-51829c6264f5%7C0db3af4ed3aa

        // AegisD - 4,000 USDS - 0x78C180CF113Fe4845C325f44648b6567BC79d6E0

        // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3

        // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // Tango - 4,000 USDS - 0xB2B86A130B1EC101e4Aed9a88502E08995760307

        // Sky Staking - 3,824 USDS - 0x05c73AE49fF0ec654496bF4008d73274a919cB5C

        // ---------- Atlas Devolopment USDS Compensation ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-october-2025/27293
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1_Atlas_Core_Development/1542d2db-be91-46f5-9d13-3a86c78b9af1|9e1f3b56

        // Kohla - 11,604 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a

        // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // Blue - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // ---------- Atlas Devolopment SKY Compensation ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-october-2025/27293
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1_Atlas_Core_Development/1542d2db-be91-46f5-9d13-3a86c78b9af1|9e1f3b56

        // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // Blue - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf

        // ---------- Spark Spell ----------
        // Forum: https://forum.sky.money/t/october-16-2025-proposed-changes-to-spark-for-upcoming-spell/27215
        // Forum: https://forum.sky.money/t/october-2-2025-proposed-changes-to-spark-for-upcoming-spell/27191
        // Forum: https://forum.sky.money/t/spark-aave-revenue-share-calculations-payments-9-q3-2025/27296
        // Poll: https://vote.sky.money/polling/QmTNrfXk

        // Approve Spark proxy spell with address TBD

        // ---------- Bloom/Grove Spell ----------
        // Forum: https://forum.sky.money/t/october-16-2025-proposed-changes-to-grove-for-upcoming-spell/27266

        // Approve Bloom/Grove proxy spell with address TBD
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
