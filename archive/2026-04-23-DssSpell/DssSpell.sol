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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface DssLitePsmLike {
    function kiss(address usr) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/ad4f3f9c5e92d42df55c2dfa5d8d60b1e4af436b/2026/executive-vote-2026-04-23-msc-staking-rewards-update.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-04-23 MakerDAO Executive Spell | Hash: 0xc8d43e739495d7eeefd521f682138555a66ac2fa1d50fa389183a603e58fb57b";

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
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable SKYBASE_SUBPROXY         = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable SPARK_SUBPROXY           = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable GROVE_SUBPROXY           = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY            = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable OBEX_SUBPROXY            = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable ALLOCATOR_SPARK_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT   = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable REWARDS_DIST_LSSKY_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable MCD_LITE_PSM_USDC_A      = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable PATTERN_STARGUARD        = DssExecLib.getChangelogAddress("PATTERN_STARGUARD");
    address internal constant  PATTERN_ALM_PROXY        = 0xbA43325E91C79E500486a23E953ab3d8C46f169F;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG   = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL = 0x160158d029697FEa486dF8968f3Be17a706dF0F0;
    bytes32 internal constant SPARK_SPELL_HASH = 0x96a0d4068774d80f3790f489aa1bbd37e45d6a019161743ad00eaf61e26466b6;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL = 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929;
    bytes32 internal constant GROVE_SPELL_HASH = 0x43fa1611223445715e33c2ad7baf836cb4c8a00a0ede6fff428b742baefa12c6;

    // ---------- Pattern Spell ----------
    address internal constant PATTERN_SPELL = 0x31831aE3C13f72afcCcf0aAF49b6f9319ed9C4C0;
    bytes32 internal constant PATTERN_SPELL_HASH = 0x1478866625ae91e3ca50fa4ff871f5721862e24b9428f15f49b093cc3305587b;

    function actions() public override {

        // ---------- Monthly Settlement Cycle for March ----------
        // Forum: https://forum.skyeco.com/t/msc-7-settlement-summary-march-2026/27844
        // Atlas: https://sky-atlas.io/#A.2.4

        // Mint 7,662,339 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 7_662_339 * WAD);

        // Send 1,725,726 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 1_725_726 * WAD);

        // Mint 6,290,684 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_290_684 * WAD);

        // Send 138,412 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 138_412 * WAD);

        // Send 30,241 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 30_241 * WAD);

        // Mint 2,075,648 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 2_075_648 * WAD);

        // Send 69,793 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 69_793 * WAD);

        // Send 225,299 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 225_299 * WAD);

        // Transfer 678,176 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 678_176 * WAD);

        // Transfer 33,908 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3)
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 33_908 * WAD);

        // ---------- Staking Rewards Update ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/14
        // Atlas: https://sky-atlas.io/#293e4c9f-1e26-4d4b-b769-650a02eca8b8
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/15

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 53,960,949 SKY
            vestTot: 53_960_949 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- ALLOCATOR-BLOOM-A DC-IAM Parameter Update ----------
        // Forum: https://forum.skyeco.com/t/atlas-edit-weekly-cycle-proposal-week-of-2026-04-20/27851
        // Poll: https://vote.sky.money/polling/QmNXSS7H

        // Increase ALLOCATOR-BLOOM-A gap by 250 million USDS from 250 million USDS to 500 million USDS
        // Leave other parameters at current values (line 5 billion USDS, ttl 24 hours)
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-BLOOM-A",
            _gap: 500 * MILLION,
            _amount: 5_000 * MILLION,
            _ttl: 24 hours
        });

        // ---------- ALLOCATOR-PATTERN-A DC-IAM Parameters Update ----------
        // Forum: https://forum.skyeco.com/t/atlas-edit-weekly-cycle-proposal-week-of-2026-04-20/27851
        // Poll: https://vote.sky.money/polling/QmNXSS7H

        // Increase ALLOCATOR-PATTERN-A gap by 40 million USDS from 10 million USDS to 50 million USDS
        // Increase ALLOCATOR-PATTERN-A line by 2.49 billion USDS from 10 million USDS to 2.5 billion USDS
        // Leave ttl at current value (24 hours)
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PATTERN-A",
            _gap: 50 * MILLION,
            _amount: 2_500 * MILLION,
            _ttl: 24 hours
        });

        // ---------- Whitelist Pattern ALMProxy on the LitePSM ----------
        // Forum: https://forum.skyeco.com/t/atlas-edit-weekly-cycle-proposal-week-of-2026-04-20/27851
        // Poll: https://vote.sky.money/polling/QmNXSS7H

        // Whitelist Pattern ALMProxy at 0xbA43325E91C79E500486a23E953ab3d8C46f169F on the LitePSM
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(PATTERN_ALM_PROXY);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-spark-for-upcoming-spell/27831
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Atlas: https://sky-atlas.io/#b69158da-476a-4d4b-b7ef-2f8b96b73d23

        // Whitelist Spark spell with address 0x160158d029697FEa486dF8968f3Be17a706dF0F0 and codehash 0x96a0d4068774d80f3790f489aa1bbd37e45d6a019161743ad00eaf61e26466b6 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829
        // Poll: https://vote.sky.money/polling/QmVAKhR6

        // Whitelist Grove spell with address 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929 and codehash 0x43fa1611223445715e33c2ad7baf836cb4c8a00a0ede6fff428b742baefa12c6 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Pattern Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: https://vote.sky.money/polling/QmVAKhR6

        // Whitelist Pattern spell with address 0x31831aE3C13f72afcCcf0aAF49b6f9319ed9C4C0 and codehash 0x1478866625ae91e3ca50fa4ff871f5721862e24b9428f15f49b093cc3305587b in PATTERN_STARGUARD, direct execution: No
        StarGuardLike(PATTERN_STARGUARD).plot(PATTERN_SPELL, PATTERN_SPELL_HASH);
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
