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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";
// Copied from https://github.com/sky-ecosystem/endgame-toolkit/blob/4f238f9b23298190150d49482bad56c00f0af825/script/dependencies/treasury-funded-farms/TreasuryFundedFarmingInit.sol
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface StUsdsRateSetterLike {
    function kiss(address usr) external;
}

interface SkyLike {
    function burn(address from, uint256 value) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface FarmOwnerLike {
    function setRewardsDuration(uint256 duration) external;
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/9dc4ca35727b6f5deaa9e5dbd1c84b6d5a112c04/2026/executive-vote-2026-10-08-stusds-keeper-launch.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-10-08 MakerDAO Executive Spell | Hash: 0x5254ff97be4a8c988ca48994d703fb6082d033d2ea6eb4b8ca142565b3e34323";

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
    uint256 internal constant WAD     = 10 ** 18;
    uint256 internal constant RAY     = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable MCD_IAM_AUTO_LINE        = DssExecLib.autoLine();
    address internal immutable STUSDS_RATE_SETTER       = DssExecLib.getChangelogAddress("STUSDS_RATE_SETTER");
    address internal constant  STUSDS_VALUE_REGISTRY    = 0xcDb55A799A9B9eAe22Ed0E13037bb6D2E3f1d080;
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
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable OSERO_STARGUARD          = DssExecLib.getChangelogAddress("OSERO_STARGUARD");
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SAFE_HARBOR_AGREEMENT    = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");

    // ---------- Wallets ----------
    address internal constant STUSDS_KEEPER_BUD            = 0x068F9c8F33E13c18B852877A5D8Ec61504971376;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0x796eE21eb57C8BE71be7F75770f534D249bC555b;
    bytes32 internal constant SPARK_SPELL_HASH = 0x06af8f55b18ae1bb19a13b9cd3531a164a53da94db01586499d9d2a22009cddb;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0x262E8baA6bFbECDD8d483d13C37c1BA7b4a861A5;
    bytes32 internal constant GROVE_SPELL_HASH = 0xb67edac3b73c41231aaa73bb69dcf7731ac1830d6af66b80be930513dc7de0b4;

    // ---------- Osero Spell ----------
    address internal constant OSERO_SPELL      = 0x0ABdd6cbb1802Ce980FE4b628a682c70727978D2;
    bytes32 internal constant OSERO_SPELL_HASH = 0xf80be0f506aab4e137a867a1c289f34254e845ecadbb92b33104660c6349a7fd;

    function actions() public override {
        // ---------- stUSDS Keeper Launch ----------
        // Forum: https://forum.skyeco.com/t/stusds-keeper-launch/28282
        // Atlas: https://sky-atlas.io/#bddf50ca-02ef-4991-abb0-53e09831ee6f

        // Kiss 0x068F9c8F33E13c18B852877A5D8Ec61504971376 on the STUSDS_RATE_SETTER
        StUsdsRateSetterLike(STUSDS_RATE_SETTER).kiss(STUSDS_KEEPER_BUD);

        // Add 0xcDb55A799A9B9eAe22Ed0E13037bb6D2E3f1d080 as STUSDS_VALUE_REGISTRY to the Chainlog
        DssExecLib.setChangelogAddress("STUSDS_VALUE_REGISTRY", STUSDS_VALUE_REGISTRY);

        // Note: bump chainlog version
        DssExecLib.setChangelogVersion("1.20.21");

        // Decrease stepStrBps (StUsdsRateSetter.strCfg.step) by 1,000 bps from 1,500 bps to 500 bps.
        // Forum: https://forum.skyeco.com/t/stusds-beam-rate-setter-configuration/27161/99
        // Atlas: https://sky-atlas.io/#91152a4b-6f97-4b8a-831a-0f85c16a78ab
        DssExecLib.setValue(STUSDS_RATE_SETTER, "STR", "step", 500);

        // Decrease stepDutyBps (StUsdsRateSetter.dutyCfg.step) by 1,000 bps from 1,500 bps to 500 bps.
        // Forum: https://forum.skyeco.com/t/stusds-beam-rate-setter-configuration/27161/99
        // Atlas: https://sky-atlas.io/#91152a4b-6f97-4b8a-831a-0f85c16a78ab
        DssExecLib.setValue(STUSDS_RATE_SETTER, "LSEV2-SKY-A", "step", 500);

        // ---------- Monthly Settlement Cycle for September 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-13-settlement-summary-september-2026/28274
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 11,627,438 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 11_627_438 * WAD);

        // Send 4,218,121 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 4_218_121 * WAD);

        // Mint 6,806,996 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_806_996 * WAD);

        // Send 1,148,408 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 1_148_408 * WAD);

        // Send 31,472 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 31_472 * WAD);

        // Mint 1,643,358 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_643_358 * WAD);

        // Send 480,680 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 480_680 * WAD);

        // Send 320,926 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 320_926 * WAD);

        // Mint 76,824 USDS debt in ALLOCATOR-PRYSM-A and transfer the amount to the surplus buffer
        _takeAllocatorPayment(ALLOCATOR_PRYSM_A_VAULT, 76_824 * WAD);

        // Send 27,661 USDS from the surplus buffer to the OSERO_SUBPROXY
        _transferUsds(OSERO_SUBPROXY, 27_661 * WAD);

        // ---------- Treasury Management Function ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/8
        // Atlas: https://sky-atlas.io/#f67a5780-11d5-4014-8254-795080c77133

        // Send 2,927,190 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 2_927_190 * WAD);

        // Burn 7,372,288 SKY tokens from the PauseProxy Balance
        SkyLike(SKY).burn(address(this), 7_372_288 * WAD);

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 99,525,882 SKY
            vestTot: 99_525_882 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // Increase splitter.hop by 189 seconds from 2,504 seconds to 2,693 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 2_693);

        // Increase rewardsDuration in REWARDS_LSSKY_USDS by 189 seconds from 2,504 seconds to 2,693 seconds
        // Note: REWARDS_LSSKY_USDS ownership was transferred to REWARDS_OWNER_LSSKY_USDS in the 2026-08-13 spell, so this has to be routed through the FarmOwner
        FarmOwnerLike(REWARDS_OWNER_LSSKY_USDS).setRewardsDuration(2_693);

        // ---------- ALLOCATOR-GROVE-A DC-IAM Parameter Adjustment ----------
        // Forum: https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255/7
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Note: Action written inline with the new parameters for ALLOCATOR-GROVE-A
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-GROVE-A",

            // Increase the Maximum Debt Ceiling (line) by 1 billion USDS from 500 million USDS to 1.5 billion USDS
            _amount: 1_500 * MILLION,

            // Increase the Target Available Debt (gap) by 125 million USDS from 25 million USDS to 150 million USDS
            _gap: 150 * MILLION,

            // Increase the Ceiling Increase Cooldown (ttl) by 43,200 seconds from 43,200 seconds to 86,400 seconds (24 hours)
            // Forum: https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255/8
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-GROVE-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-GROVE-A");

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](2);

        // Add accounts to eip155:1 chain: 0xcDb55A799A9B9eAe22Ed0E13037bb6D2E3f1d080
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30786344623535413739394139423965416532324564304531333033376262364432453366316430383000000000000000000000000000000000000000000000';

        // Add accounts to eip155:42161 chain: 0x11CFefeA67B18de9046a6250555D438854fFEEDa, 0xd11Dc57F3eF23bb7b3142588a461F68460a7C474, 0x66d3653e66F7edb973549CFA3b46F22298B8f983, 0xeCCA0D296Cb133081d41E9772B60D57F5fd2798E, 0x86036CE5d2f792367C0AA43164e688d13c5A60A8, 0x3968a022D955Bbb7927cc011A48601B65a33F346, 0xCBA0C0a2a0B6Bb11233ec4EA85C5bFfea33e724d
        calldatas[1] = hex'46c2b73400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000c6569703135353a34323136310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002c00000000000000000000000000000000000000000000000000000000000000360000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078313143466566654136374231386465393034366136323530353535443433383835346646454544610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078643131446335374633654632336262376233313432353838613436314636383436306137433437340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078363664333635336536364637656462393733353439434641336234364632323239384238663938330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078654343413044323936436231333330383164343145393737324236304435374635666432373938450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078383630333643453564326637393233363743304141343331363465363838643133633541363041380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078333936386130323244393535426262373932376363303131413438363031423635613333463334360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a30784342413043306132613042364262313132333365633445413835433562466665613333653732346400000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-spark-for-upcoming-spell/28265
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xff837d7434b33bc2d74a133e5c2acbcdf2ff17e6b76005621cfd43794f0d85cb
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x93fd7352008805e27da235e51c02e7c987ff5d0ee3feccd3cd157e09a2e9adfe
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x4680fb4b5717156b6e53f858ab6a267190deab0d51380b5fb9d27910e09d4e74
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x84f74256a6f0e41078483b5c7ce8dad4b885f5bc656a5bcaccb84f36d74e536c
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xeaab1672f63e49d6075eefbede7cab3fac3db3bba3c2f486eee7bb492d82ff3e
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0x796eE21eb57C8BE71be7F75770f534D249bC555b and codehash 0x06af8f55b18ae1bb19a13b9cd3531a164a53da94db01586499d9d2a22009cddb in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x515fa8cf35a8ee5bd39a8a5b55dfad3f1e8f0ecb1e4678f8de83bfe892f28dc3
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0xf97cae9eb7937f48c92b268b3f28886f9dcc5fd05e3d39fb1b67ccf2ec16ca4d
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0xf11bc85d5b66a8e8a4a6793c348d266a0af816dfbc332b905317344d9d375ef1

        // Whitelist Grove spell with address 0x262E8baA6bFbECDD8d483d13C37c1BA7b4a861A5 and codehash 0xb67edac3b73c41231aaa73bb69dcf7731ac1830d6af66b80be930513dc7de0b4 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-osero-for-upcoming-spell/28253
        // Poll: https://vote.sky.money/polling/Qmb2Cmnf

        // Whitelist Osero spell with address 0x0ABdd6cbb1802Ce980FE4b628a682c70727978D2 and codehash 0xf80be0f506aab4e137a867a1c289f34254e845ecadbb92b33104660c6349a7fd in OSERO_STARGUARD, direct execution: No
        StarGuardLike(OSERO_STARGUARD).plot(OSERO_SPELL, OSERO_SPELL_HASH);
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

    /// @notice Wraps the operations required to update the Safe Harbor agreement.
    /// @dev This function executes pre-encoded function calls on the Safe Harbor agreement contract.
    ///      The calldatas array contains ABI-encoded function calls (selector + parameters) that
    ///      will be executed sequentially on the Safe Harbor agreement contract.
    /// @param calldatas Array of ABI-encoded function calls to execute on the Safe Harbor agreement contract
    function _updateSafeHarbor(bytes[] memory calldatas) internal {
        for (uint256 i = 0; i < calldatas.length; i++) {
            (bool success,) = SAFE_HARBOR_AGREEMENT.call(calldatas[i]);
            require(success, "updateSafeHarbor/safe-harbor-update-failed");
        }
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
