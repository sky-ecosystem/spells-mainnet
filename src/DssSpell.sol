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
import { WardsAbstract } from "dss-interfaces/utils/WardsAbstract.sol";


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

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-09-18 MakerDAO Executive Spell | Hash: TODO";

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

    // ---------- Contracts ----------
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MKR_SKY                  = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable USDS                     = DssExecLib.getChangelogAddress("USDS");
    address internal immutable ALLOCATOR_ROLES          = DssExecLib.getChangelogAddress("ALLOCATOR_ROLES");
    address internal immutable ALLOCATOR_NOVA_A_VAULT   = DssExecLib.getChangelogAddress("ALLOCATOR_NOVA_A_VAULT");
    address internal immutable ALLOCATOR_NOVA_A_BUFFER  = DssExecLib.getChangelogAddress("ALLOCATOR_NOVA_A_BUFFER");
    address internal immutable MCD_PAUSE_PROXY          = DssExecLib.getChangelogAddress("MCD_PAUSE_PROXY");

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

    // ---------- Nova Proxy ----------
    address internal constant NOVA_PROXY = 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310;

    function actions() public override {

    // ---------- Delayed Upgrade Penalty ----------

    // File 1% fee on MKR_SKY
    DssExecLib.setValue(MKR_SKY, "fee", 1 * WAD / 100);

    // ---------- Replace Nova Operator ----------

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
    WardsAbstract(ALLOCATOR_NOVA_A_VAULT).deny(MCD_PAUSE_PROXY);

    // WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).rely(NOVA_PROXY);
    WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).rely(NOVA_PROXY);

    // WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).deny(MCD_PAUSE_PROXY);
    WardsAbstract(ALLOCATOR_NOVA_A_BUFFER).deny(MCD_PAUSE_PROXY);

    // ---------- LSEV2-SKY-A Liquidation Ratio increase ----------

    // Increase LSEV2-SKY-A Liquidation Ratio for 20 percentage points, from 125% to 145%
    DssExecLib.setIlkLiquidationRatio("LSE-MKR-A", 145_00);

    // ---------- First Settlement Cycle ----------

    // TBC

    // ---------- AD compensation ----------

    // BLUE - 4,000 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
    _transferUsds(BLUE, 4000 * WAD);

    // Bonapublica - 4,000 USDS - 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
    _transferUsds(BONAPUBLICA, 4000 * WAD);

    // Cloaky - 4,000 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
    _transferUsds(CLOAKY_2, 4000 * WAD);

    // WBC - 4,000 USDS - 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47
    _transferUsds(WBC, 4000 * WAD);

    // Tango - 3,400 USDS - 0xB2B86A130B1EC101e4Aed9a88502E08995760307
    _transferUsds(TANGO, 3400 * WAD);

    // Sky Staking - 2,854 USDS - 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
    _transferUsds(SKY_STAKING, 2854 * WAD);

    // AegisD - 645 USDS - 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
    _transferUsds(AEGIS_D, 645 * WAD);

    // ---------- Atlas Core Development USDS Payments for September 2025 ----------

    // Kohla - 11,140 USDS - 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a
    _transferUsds(CLOAKY_KOHLA_2, 11140 * WAD);

    // Cloaky - 16,417 USDS - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
    _transferUsds(CLOAKY_2, 16417 * WAD);

    // Blue - 50,167 USDS - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
    _transferUsds(BLUE, 50167 * WAD);

    // ---------- Atlas Core Development SKY Payments for September 2025 ----------

    // Cloaky - 288,000 SKY - 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
    GemAbstract(SKY).transfer(CLOAKY_2, 288000 * WAD);

    // Blue - 330,000 SKY - 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
    GemAbstract(SKY).transfer(BLUE, 330000 * WAD);

    // ---------- Execute Spark Proxy Spell ----------

    // Execute Spark proxy spell at TBC

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
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
