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

import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

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

    // ---------- Math ----------
    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable MCD_VAT                 = DssExecLib.vat();
    address internal immutable MCD_JUG                 = DssExecLib.jug();
    address internal immutable MCD_VOW                 = DssExecLib.vow();
    address internal immutable SKY                     = DssExecLib.getChangelogAddress("SKY");
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");

    // ---------- Wallets ----------
    address internal constant AEGIS_D        = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
    address internal constant BLUE           = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA    = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2       = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant TANGO          = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant SKY_STAKING    = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;
    address internal constant CLOAKY_KOHLA_2 = 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a;

    // ---------- Spark Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    // ---------- Bloom/Grove Spell ----------
    // Note: The deployment address of the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant GROVE_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;

    function actions() public override {
        // ---------- Lssky-SKY Farm Initialization ----------

        // ---------- Obex Allocator Initialization ----------

        // ---------- Monthly Settlement Cycle #2 ----------
        // Forum: https://forum.sky.money/t/msc-2-settlement-summary-september-2025-spark-only-initial-calculations/27286/2
        // Atlas: https://sky-atlas.powerhouse.io/A.2.5.1.2.2.1_Stage_1/241f2ff0-8d73-8014-b124-e76f5f5c91fc%7C9e1fcc279923ea16fa2d

        // Spark
        // Note: This is only a subheading, actual instructions follow below.

        // Mint 16,931,086 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_931_086 * WAD);

        // Send 3,827,201 USDS to 0x3300f198988e4C9C63F75dF86De36421f06af8c4 (Spark SubProxy)
        _transferUsds(SPARK_PROXY, 3_827_201 * WAD);

        // Bloom/Grove
        // Note: This is only a subheading, actual instructions follow below.

        // Mint 6,382,973 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_382_973 * WAD);

        // Send 104,924 USDS to 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba (Grove SubProxy)
        _transferUsds(GROVE_PROXY, 104_924 * WAD);

        // ---------- Ranked Delegate Compensation ----------
        // Forum: https://forum.sky.money/t/september-2025-ranked-delegate-compensation/27305
        // Atlas: https://sky-atlas.powerhouse.io/A.1.5.6.1_Budget_Amount_For_Ranked_Delegate_Slots/a8a767c3-9594-4e84-aa14-51829c6264f5%7C0db3af4ed3aa

        // AegisD - 4,000 USDS - 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        _transferUsds(AEGIS_D, 4_000 * WAD);

        // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // Tango - 4,000 USDS - 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 4_000 * WAD);

        // Sky Staking - 3,824 USDS - 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        _transferUsds(SKY_STAKING, 3_824 * WAD);

        // ---------- Atlas Devolopment USDS Compensation ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-october-2025/27293
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1_Atlas_Core_Development/1542d2db-be91-46f5-9d13-3a86c78b9af1|9e1f3b56

        // Kohla - 11,604 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a
        _transferUsds(CLOAKY_KOHLA_2, 11_604 * WAD);

        // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // Blue - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // ---------- Atlas Devolopment SKY Compensation ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-october-2025/27293
        // Atlas: https://sky-atlas.powerhouse.io/A.2.2.1_Atlas_Core_Development/1542d2db-be91-46f5-9d13-3a86c78b9af1|9e1f3b56

        // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // Blue - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

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

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
    /// @param usr The USDS receiver.
    /// @param wad The USDS amount in wad precision (10 ** 18).
    function _transferUsds(address usr, uint256 wad) internal {
        // Note: Enforce whole units to avoid rounding errors
        require(wad % WAD == 0, "transferUsds/non-integer-wad");
        // Note: DssExecLib currently only supports Dai transfers from the surplus buffer.
        DssExecLib.sendPaymentFromSurplusBuffer(address(this), wad / WAD);
        // Note: Approve DAI_USDS for the amount sent to be able to convert it.
        GemAbstract(DAI).approve(DAI_USDS, wad);
        // Note: Convert Dai to USDS for `usr`.
        DaiUsdsLike(DAI_USDS).daiToUsds(usr, wad);
    }

    /// @notice Wraps the operations required to take a payment from a Prime agent
    /// @dev This function effectively increases the debt of the associated Allocator Vault,
    ///      regardless if there is enough room in its debt ceiling.
    /// @param vault The address of the allocator vault
    /// @param wad The amount in wad precision (10 ** 18)
    function _takeAllocatorPayment(address vault, uint256 wad) internal {
        require(wad > 0, "takeAllocatorPayment/zero-amount");
        bytes32 ilk = AllocatorVaultLike(vault).ilk();
        uint256 rate = JugAbstract(MCD_JUG).drip(ilk);
        require(rate > 0, "takeAllocatorPayment/jug-ilk-not-initialized");
        // Note: divup - rounds up in favor of Core.
        uint256 dart = ((wad * RAY - 1) / rate) + 1;
        require(dart <= uint256(type(int256).max), "takeAllocatorPayment/dart-too-large");
        // Note: Take the amount needed, but keep it in the Vow.
        //       This basically generates both sin[vow] and dai[vow] at the same time.
        VatAbstract(MCD_VAT).suck(MCD_VOW, MCD_VOW, dart * rate);
        // Note: Increase the outsdanding debt of the vault, while reducing sin[vow], canceling out the sin generated by vat.suck.
        //       The net effect is that dai[vow] and urn[vault].art increase.
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
