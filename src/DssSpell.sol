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
import { DssExecLib } from "dss-exec-lib/DssExecLib.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { WardsAbstract } from "dss-interfaces/utils/WardsAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";

interface AllocatorBufferLike {
    function approve(address asset, address spender, uint256 amount) external;
}

interface AllocatorRolesLike {
    function setRoleAction(bytes32 ilk, uint8 role, address target, bytes4 sig, bool enabled) external;
    function setUserRole(bytes32 ilk, address who, uint8 role, bool enabled) external;
    function setIlkAdmin(bytes32 ilk, address usr) external;
}

interface VaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

interface DaiUsdsLike {
    function daiToUsds(address, uint256) external;
}

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

abstract contract DssAction {

    using DssExecLib for *;

    // Modifier used to limit execution time when office hours is enabled
    modifier limited {
        require(DssExecLib.canCast(uint40(block.timestamp), officeHours()), "Outside office hours");
        _;
    }

    // Office Hours defaults to true by default.
    //   To disable office hours, override this function and
    //    return false in the inherited action.
    function officeHours() public view virtual returns (bool) {
        return true;
    }

    // DssExec calls execute. We limit this function subject to officeHours modifier.
    function execute() external limited {
        actions();
    }

    // DssAction developer must override `actions()` and place all actions to be called inside.
    //   The DssExec function will call this subject to the officeHours limiter
    //   By keeping this function public we allow simulations of `execute()` on the actions outside of the cast time.
    function actions() public virtual;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://<executive-vote-canonical-post> -q -O - 2>/dev/null)"
    function description() external view virtual returns (string memory);

    // Returns the next available cast time
    function nextCastTime(uint256 eta) external virtual view returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
    }
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-09-18 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return false;
    }

    // ---------- Set earliest execution date September 22, 14:00 UTC ----------

    // Note: 2025-09-22 14:00:00 UTC
    uint256 internal constant SEP_22_2025 = 1758542400;

    // Note: Override nextCastTime to inform keepers about the earliest execution time
    function nextCastTime(uint256 eta) external view override returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        // Note: First calculate the standard office hours cast time
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
        // Note: Then ensure it's not before our minimum date
        return castTime < SEP_22_2025 ? SEP_22_2025 : castTime;
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
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MKR_SKY                  = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable USDS                     = DssExecLib.getChangelogAddress("USDS");
    address internal immutable ALLOCATOR_ROLES          = DssExecLib.getChangelogAddress("ALLOCATOR_ROLES");
    address internal immutable ALLOCATOR_NOVA_A_VAULT   = DssExecLib.getChangelogAddress("ALLOCATOR_NOVA_A_VAULT");
    address internal immutable ALLOCATOR_NOVA_A_BUFFER  = DssExecLib.getChangelogAddress("ALLOCATOR_NOVA_A_BUFFER");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_SPARK_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");

    // ---------- Wallets ----------
    address internal constant NOVA_OPERATOR  = 0x0f72935f6de6C54Ce8056FD040d4Ddb012B7cd54;
    address internal constant BLUE           = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA    = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2       = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant WBC            = 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47;
    address internal constant TANGO          = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant AEGIS_D        = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
    address internal constant CLOAKY_KOHLA_2 = 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a;
    address internal constant SKY_STAKING    = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;

    // ---------- Grove Proxy ----------
    // Note: The deployment address of the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant GROVE_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;

    // ---------- Nova Proxy ----------
    // Note: The deployment address of the Nova Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-nova-allocator-adjustment/27175
    address internal constant NOVA_PROXY = 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310;

    // ---------- Spark Proxy Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0x7B28F4Bdd7208fe80916EBC58611Eb72Fb6A09Ed;

    function actions() public override {
        // ---------- Set earliest execution date September 22, 14:00 UTC ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-september-18th-spell/27178
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.1.4.2.5_Set_Conversion_Fee_In_MKR_To_SKY_Conversion_Contract_To_1%25/1f1f2ff0-8d73-804c-948b-fddc869fcb65%7Cb341f4c0b83472dc1f9e1a3b

        require(block.timestamp >= SEP_22_2025, "Spell can only be cast after Sep 22, 2025, 14:00 UTC");

        // ---------- Delayed Upgrade Penalty ----------
        // Forum: https://forum.sky.money/t/phase-3-mkr-to-sky-migration-items-september-18th-spell/27178
        // Atlas: https://sky-atlas.powerhouse.io/A.4.1.2.1.4.2.5_Set_Conversion_Fee_In_MKR_To_SKY_Conversion_Contract_To_1%25/1f1f2ff0-8d73-804c-948b-fddc869fcb65%7Cb341f4c0b83472dc1f9e1a3b

        // File 1% fee on MKR_SKY
        DssExecLib.setValue(MKR_SKY, "fee", 1 * WAD / 100);

        // ---------- Replace Nova Operator ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-nova-allocator-adjustment/27175
        // Forum: https://forum.sky.money/t/technical-scope-of-the-nova-allocator-adjustment/27175/2
        // Poll: https://vote.sky.money/polling/QmYt7nbx

        // AllocatorBufferLike(ALLOCATOR_NOVA_A_BUFFER).approve(USDS, NOVA_OPERATOR, 0);
        AllocatorBufferLike(ALLOCATOR_NOVA_A_BUFFER).approve(USDS, NOVA_OPERATOR, 0);

        // AllocatorRolesLike(ALLOCATOR_ROLES).setUserRole("ALLOCATOR-NOVA-A", NOVA_OPERATOR, 0, false);
        AllocatorRolesLike(ALLOCATOR_ROLES).setUserRole("ALLOCATOR-NOVA-A", NOVA_OPERATOR, 0, false);

        // AllocatorRolesLike(ALLOCATOR_ROLES).setRoleAction("ALLOCATOR-NOVA-A", 0, ALLOCATOR_NOVA_A_VAULT, VaultLike.draw.selector, false);
        AllocatorRolesLike(ALLOCATOR_ROLES).setRoleAction("ALLOCATOR-NOVA-A", 0, ALLOCATOR_NOVA_A_VAULT, VaultLike.draw.selector, false);

        // AllocatorRolesLike(ALLOCATOR_ROLES).setRoleAction("ALLOCATOR-NOVA-A", 0, ALLOCATOR_NOVA_A_VAULT, VaultLike.wipe.selector, false);
        AllocatorRolesLike(ALLOCATOR_ROLES).setRoleAction("ALLOCATOR-NOVA-A", 0, ALLOCATOR_NOVA_A_VAULT, VaultLike.wipe.selector, false);

        // AllocatorRolesLike(ALLOCATOR_ROLES).setIlkAdmin("ALLOCATOR-NOVA-A", NOVA_PROXY);
        AllocatorRolesLike(ALLOCATOR_ROLES).setIlkAdmin("ALLOCATOR-NOVA-A", NOVA_PROXY);

        // WardsAbstract(ALLOCATOR_NOVA_A_VAULT).rely(NOVA_PROXY);
        WardsAbstract(ALLOCATOR_NOVA_A_VAULT).rely(NOVA_PROXY);

        // WardsAbstract(ALLOCATOR_NOVA_A_VAULT).deny(MCD_PAUSE_PROXY);
        WardsAbstract(ALLOCATOR_NOVA_A_VAULT).deny(address(this));

        // WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).rely(NOVA_PROXY);
        WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).rely(NOVA_PROXY);

        // WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).deny(MCD_PAUSE_PROXY);
        WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).deny(address(this));

        // ---------- LSEV2-SKY-A Liquidation Ratio increase ----------
        // Forum: https://forum.sky.money/t/september-18-2025-proposed-changes-to-lsev2-sky-a-liquidation-ratio/27160
        // Forum: https://forum.sky.money/t/september-18-2025-proposed-changes-to-lsev2-sky-a-liquidation-ratio/27160/2

        // Increase LSEV2-SKY-A Liquidation Ratio for 20 percentage points, from 125% to 145%
        DssExecLib.setIlkLiquidationRatio("LSE-MKR-A", 145_00);

        // ---------- First Settlement Cycle ----------
        // Forum: https://forum.sky.money/t/monthly-settlement-cycle-1-july-august-september-18-2025-spell/27173
        // Atlas: https://sky-atlas.powerhouse.io/A.2.5.1.2.2.1_Stage_1/241f2ff0-8d73-8014-b124-e76f5f5c91fc%7C9e1fcc279923ea16fa2d

        // _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 4_788_407e18);
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 4_788_407 * WAD);

        // _transferUsds(GROVE_PROXY: 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba, 30_654e18);
        _transferUsds(GROVE_PROXY, 30_654 * WAD);

        // _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 1_603_952e18);
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 1_603_952 * WAD);

        // _transferUsds(SPARK_PROXY: 0x3300f198988e4C9C63F75dF86De36421f06af8c4, 5_927_944e18);
        _transferUsds(SPARK_PROXY, 5_927_944 * WAD);

        // ---------- AD compensation ----------
        // Forum: https://forum.sky.money/t/august-2025-aligned-delegate-compensation/27165
        // Atlas: https://sky-atlas.powerhouse.io/Budget_And_Participation_Requirements/4c698938-1a11-4486-a568-e54fc6b0ce0c%7C0db3af4e

        // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // WBC - 4,000 USDS - 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47
        _transferUsds(WBC, 4_000 * WAD);

        // Tango - 3,400 USDS - 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 3_400 * WAD);

        // Sky Staking - 2,854 USDS - 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        _transferUsds(SKY_STAKING, 2_854 * WAD);

        // AegisD - 645 USDS - 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        _transferUsds(AEGIS_D, 645 * WAD);

        // ---------- Atlas Core Development USDS Payments for September 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-september-2025/27139
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-september-2025/27139/6

        // Kohla - 11,140 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a
        _transferUsds(CLOAKY_KOHLA_2, 11_140 * WAD);

        // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // Blue - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // ---------- Atlas Core Development SKY Payments for September 2025 ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-september-2025/27139
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-september-2025/27139/6

        // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // Blue - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

        // ---------- Execute Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/september-18-2025-proposed-changes-to-spark-for-upcoming-spell/27153
        // Poll: https://vote.sky.money/polling/QmUaV3Xj
        // Poll: https://vote.sky.money/polling/QmPT2Ynb
        // Poll: https://vote.sky.money/polling/QmVwqNSv
        // Poll: https://vote.sky.money/polling/QmXzyYyJ
        // Poll: https://vote.sky.money/polling/QmUv9fbY
        // Poll: https://vote.sky.money/polling/Qme1KAbo
        // Poll: https://vote.sky.money/polling/QmdX2eGt
        // Poll: https://vote.sky.money/polling/QmeyqTyQ
        // Poll: https://vote.sky.money/polling/Qmc8PHPC
        // Poll: https://vote.sky.money/polling/QmbHt4Vg

        // Execute Spark proxy spell at 0x7B28F4Bdd7208fe80916EBC58611Eb72Fb6A09Ed
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));
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
    /// @param vault The address of the allocator vault
    /// @param wad The amount in wad precision (10 ** 18)
    function _takeAllocatorPayment(address vault, uint256 wad) internal {
        bytes32 ilk = AllocatorVaultLike(vault).ilk();
        uint256 rate = JugAbstract(MCD_JUG).drip(ilk);
        uint256 dart = wad * RAY != 0 ? ((wad * RAY - 1) / rate) + 1 : 0;
        require(dart <= uint256(type(int256).max));
        VatAbstract(MCD_VAT).suck(MCD_VOW, MCD_VOW, dart * rate);
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
