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
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";
// Copied from https://github.com/sky-ecosystem/endgame-toolkit/blob/4f238f9b23298190150d49482bad56c00f0af825/script/dependencies/treasury-funded-farms/TreasuryFundedFarmingInit.sol
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface SkyLike {
    function burn(address from, uint256 value) external;
}

interface FarmOwnerLike {
    function setRewardsDuration(uint256 duration) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/2b4a918f5f5456df24ffa9f5162194f2c7f48a51/2026/executive-vote-2026-09-10-august-msc-lssky-staking-rewards-update-sky-burn.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-09-10 MakerDAO Executive Spell | Hash: 0x066eb87be8e96fa50531a05c521a9c6b7d899659a9d6f850731e7d7ec9f58a49";

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

    // ---------- Math ----------
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;
    uint256 internal constant RAY     = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable MCD_IAM_AUTO_LINE        = DssExecLib.autoLine();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable ALLOCATOR_SPARK_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable SPARK_SUBPROXY           = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable GROVE_SUBPROXY           = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY            = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable ALLOCATOR_OBEX_A_VAULT   = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable OBEX_SUBPROXY            = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY         = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable ALLOCATOR_PRYSM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_PRYSM_A_VAULT");
    address internal immutable OSERO_SUBPROXY           = DssExecLib.getChangelogAddress("OSERO_SUBPROXY");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable REWARDS_DIST_LSSKY_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable MCD_SPLIT                = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable REWARDS_OWNER_LSSKY_USDS = DssExecLib.getChangelogAddress("REWARDS_OWNER_LSSKY_USDS");
    address internal immutable MKR_SKY                  = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0x7602cc457786c06778258A0b004f2D66c54386fC;
    bytes32 internal constant SPARK_SPELL_HASH = 0xb3b1f22f29ef3d269404004599f13b840e45ec98909ac3de529e27c155bed088;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0x73F9798B24b7843B8028f905373124EfCAF25Da4;
    bytes32 internal constant GROVE_SPELL_HASH = 0xc72bda25146c6225b10ee085a10e21b0126b34dde6036a24d7023142846d34c0;

    function actions() public override {
        // ---------- Monthly Settlement Cycle for August 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-12-settlement-summary-august-2026/28217
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 6,357,912 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 6_357_912 * WAD);

        // Send 937,436 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 937_436 * WAD);

        // Mint 9,574,714 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 9_574_714 * WAD);

        // Send 1,342,064 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 1_342_064 * WAD);

        // Send 31,776 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 31_776 * WAD);

        // Mint 1,631,729 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_631_729 * WAD);

        // Send 458,340 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 458_340 * WAD);

        // Send 101,204 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 101_204 * WAD);

        // Mint 7,006 USDS debt in ALLOCATOR-PRYSM-A and transfer the amount to the surplus buffer
        _takeAllocatorPayment(ALLOCATOR_PRYSM_A_VAULT, 7_006 * WAD);

        // Send 30,156 USDS from the surplus buffer to the OSERO_SUBPROXY
        _transferUsds(OSERO_SUBPROXY, 30_156 * WAD);

        // Send 3,149,060 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/5
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_149_060 * WAD);

        // ---------- Treasury Management Function ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/5
        // Atlas: https://sky-atlas.io/#f67a5780-11d5-4014-8254-795080c77133

        // Burn 2,860,943.76 SKY tokens from the PauseProxy Balance
        // Note: `ether` is only used as a keyword. Only SKY is being burned.
        SkyLike(SKY).burn(address(this), 2_860_943.76 ether);

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 143,208,393 SKY
            vestTot: 143_208_393 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // Decrease splitter.hop by 1,244 seconds from 3,748 seconds to 2,504 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 2_504);

        // Decrease rewardsDuration in REWARDS_LSSKY_USDS by 1,244 seconds from 3,748 seconds to 2,504 seconds
        // Note: REWARDS_LSSKY_USDS ownership was transferred to REWARDS_OWNER_LSSKY_USDS in the 2026-08-13 spell, so this has to be routed through the FarmOwner
        FarmOwnerLike(REWARDS_OWNER_LSSKY_USDS).setRewardsDuration(2_504);

        // ---------- Increase the MKR-SKY Delayed Upgrade Penalty ----------
        // Forum: https://forum.skyeco.com/t/delayed-migration-penalty-update-september-10th-spell/28218
        // Atlas: https://sky-atlas.io/#ec820ddb-5d12-43d8-81b7-a7602a70332a

        // Increase the Delayed Upgrade Penalty for MKR-SKY conversions by 1 percentage point from 4% to 5%
        DssExecLib.setValue(MKR_SKY, "fee", 5 * WAD / 100);

        // ---------- Adjust ALLOCATOR-GROVE-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/september-10-2026-proposed-changes-to-grove-for-upcoming-spell/28207/6
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-GROVE-A",
            // Increase ALLOCATOR-GROVE-A line by 75 million USDS from 25 million USDS to 100 million USDS
            _amount: 100 * MILLION,
            // Increase ALLOCATOR-GROVE-A gap by 10 million USDS from 5 million USDS to 15 million USDS
            _gap: 15 * MILLION,
            // Decrease ALLOCATOR-GROVE-A ttl by 43,200 seconds from 86,400 seconds to 43,200 seconds (12 hours)
            _ttl: 43_200 seconds
        });

        // Note: Apply the updated ALLOCATOR-GROVE-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-GROVE-A");

        // ---------- Adjust ALLOCATOR-PRYSM-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/sep-10-2026-osero-requested-changes-to-allocator-vault-parameters/28211
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PRYSM-A",
            // Increase ALLOCATOR-PRYSM-A line by 75 million USDS from 25 million USDS to 100 million USDS
            _amount: 100 * MILLION,
            // Increase ALLOCATOR-PRYSM-A gap by 10 million USDS from 5 million USDS to 15 million USDS
            _gap: 15 * MILLION,
            // Leave ALLOCATOR-PRYSM-A ttl unchanged at 86,400 seconds (24 hours)
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-PRYSM-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-PRYSM-A");

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/september-10-2026-proposed-changes-to-spark-for-upcoming-spell/28208
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xce102fe51d0f9dffa64c47df88974e52899ce5347375854adfe3547225489421
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x95329a02677772384f4d2bad196de1f2b0fe6b83a06ab61fe634fb07643dcb86

        // Whitelist Spark spell with address 0x7602cc457786c06778258A0b004f2D66c54386fC and codehash 0xb3b1f22f29ef3d269404004599f13b840e45ec98909ac3de529e27c155bed088 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/september-10-2026-proposed-changes-to-grove-for-upcoming-spell/28207
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x1c152d7efd78b8cc72bec0af156d60ead97578bf11285a2c51e84d8adf2dbaba

        // Whitelist Grove spell with address 0x73F9798B24b7843B8028f905373124EfCAF25Da4 and codehash 0xc72bda25146c6225b10ee085a10e21b0126b34dde6036a24d7023142846d34c0 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
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
        // Note: Increase the outstanding debt of the vault, while reducing sin[vow], canceling out the sin generated by vat.suck.
        //       The net effect is that dai[vow] and urn[vault].art increase.
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
