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
import { StarGuardInit, StarGuardConfig } from "src/dependencies/star-guard/StarGuardInit.sol";

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
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
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/4b4513a56cf4755dfa04bc80380b05776c873f86/2026/executive-vote-2026-03-26-agent-onboardings-genesis-funding.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-03-26 MakerDAO Executive Spell | Hash: 0x3e4c6cf37f0dce0f43c977873275e7b6a1016a0f032bb32093f041e85d234437";

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
    address internal immutable CHAINLOG                = DssExecLib.LOG;
    address internal immutable CRON_STARGUARD_JOB      = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");
    address internal immutable MCD_JUG                 = DssExecLib.jug();
    address internal immutable MCD_VAT                 = DssExecLib.vat();
    address internal immutable MCD_VOW                 = DssExecLib.vow();
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable SAFE_HARBOR_AGREEMENT   = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");
    address internal immutable KEEL_SUBPROXY           = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable PRYSM_SUBPROXY          = DssExecLib.getChangelogAddress("PRYSM_SUBPROXY");
    address internal immutable SPARK_SUBPROXY          = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable GROVE_SUBPROXY          = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable OBEX_SUBPROXY           = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY        = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable SPARK_STARGUARD         = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD         = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");

    address internal constant OZONE_SUBPROXY           = 0x9FE628BFc33f0352Bb1f93168881a9Ef93C8d2CF;
    address internal constant OZONE_STARGUARD          = 0x9803DA8a51Fa02EEbEc3B1b969a9B80f9115cD80;
    address internal constant AMATSU_SUBPROXY          = 0xF33B14329e7115dD0B40DBb2985E1A0Df10E3fAa;
    address internal constant AMATSU_STARGUARD         = 0xF7469b6db1FDD3354969605e168585b8eeB5F08D;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG   = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0xe854CE4A58eC1BAf997ccA483de26B0935Ae0f45;
    bytes32 internal constant SPARK_SPELL_HASH = 0xc941bea37a2ac710acd87d9c097f9ff23f44d43121857dd8fde7833964c7c280;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0x78e187473527938211187C85a414b19dD34ECD53;
    bytes32 internal constant GROVE_SPELL_HASH = 0xa0162bcb9891a8c322c525502626282d5fc545bfb5ef2251b06c75f674af681f;

    function actions() public override {
        // ---------- Ozone Onboarding ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-ozone-executor-agent/27779
        // Poll: https://vote.sky.money/polling/QmZRHXrp

        // Init new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x9FE628BFc33f0352Bb1f93168881a9Ef93C8d2CF
                subProxy: OZONE_SUBPROXY,
                // cfg.subProxyKey: OZONE_SUBPROXY
                subProxyKey: "OZONE_SUBPROXY",
                // cfg.starGuard: 0x9803DA8a51Fa02EEbEc3B1b969a9B80f9115cD80
                starGuard: OZONE_STARGUARD,
                // cfg.starGuardKey: OZONE_STARGUARD
                starGuardKey: "OZONE_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add OZONE_STARGUARD module to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(OZONE_STARGUARD);

        // ---------- Amatsu Onboarding ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-amatsu-executor-agent/27780
        // Poll: https://vote.sky.money/polling/QmZRHXrp

        // Init new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0xF33B14329e7115dD0B40DBb2985E1A0Df10E3fAa
                subProxy: AMATSU_SUBPROXY,
                // cfg.subProxyKey: AMATSU_SUBPROXY
                subProxyKey: "AMATSU_SUBPROXY",
                // cfg.starGuard: 0xF7469b6db1FDD3354969605e168585b8eeB5F08D
                starGuard: AMATSU_STARGUARD,
                // cfg.starGuardKey: AMATSU_STARGUARD
                starGuardKey: "AMATSU_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add AMATSU_STARGUARD module to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(AMATSU_STARGUARD);

        // Note: bump Chainlog patch version to reflect the additions of the new SubProxy and StarGuard addresses
        DssExecLib.setChangelogVersion("1.20.14");

        // ---------- Genesis Funding Transfers ----------
        // Forum: https://forum.skyeco.com/t/atlas-edit-weekly-cycle-proposal-week-of-2026-03-16/27767
        // Poll: https://vote.sky.money/polling/QmZRHXrp

        // Transfer 25 million USDS to the AMATSU_SUBPROXY
        _transferUsds(AMATSU_SUBPROXY, 25_000_000 * WAD);

        // Transfer 25 million USDS to the OZONE_SUBPROXY
        _transferUsds(OZONE_SUBPROXY, 25_000_000 * WAD);

        // Transfer 10 million USDS to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 10_000_000 * WAD);

        // Transfer 10 million USDS to the PRYSM_SUBPROXY
        _transferUsds(PRYSM_SUBPROXY, 10_000_000 * WAD);

        // ---------- Monthly Settlement Cycle for February 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-6-settlement-summary-february-2026/27778
        // Atlas: https://sky-atlas.io/#A.2.4

        // Mint 7,746,811 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 7_746_811 * WAD);

        // Send 1,265,132 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 1_265_132 * WAD);

        // Mint 6,346,829 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_346_829 * WAD);

        // Send 5,630 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 5_630 * WAD);

        // Mint 1,948,422 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_948_422 * WAD);

        // Send 65,719 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 65_719 * WAD);

        // Send 203,134 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 203_134 * WAD);

        // Transfer 2,545,907 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 2_545_907 * WAD);

        // Transfer 127,295 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3)
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 127_295 * WAD);

        // ---------- Safe Harbor Update ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        // ---------- Bug Bounty Updates ----------
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:1 chain: 0x9FE628BFc33f0352Bb1f93168881a9Ef93C8d2CF, 0x9803DA8a51Fa02EEbEc3B1b969a9B80f9115cD80, 0xF33B14329e7115dD0B40DBb2985E1A0Df10E3fAa, 0xF7469b6db1FDD3354969605e168585b8eeB5F08D
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078394645363238424663333366303335324262316639333136383838316139456639334338643243460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078393830334441386135314661303245456245633342316239363961394238306639313135634438300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078463333423134333239653731313564443042343044426232393835453141304466313045336641610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30784637343639623664623146444433333534393639363035653136383538356238656542354630384400000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/march-26-2026-proposed-changes-to-spark-for-upcoming-spell/27770
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.4
        // Poll: https://vote.sky.money/polling/QmX7MC2S
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x2ca62cbabf82254f8df685e73a4a7751cf6cf26a8ce8ccfd706c9063f27061c7
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x71d2b7802b54a579655ca9c1aca12e6256d2ea3dd8951fdfa39cd7da4524c75e

        // Whitelist Spark spell with address 0xe854CE4A58eC1BAf997ccA483de26B0935Ae0f45 and codehash 0xc941bea37a2ac710acd87d9c097f9ff23f44d43121857dd8fde7833964c7c280 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/march-26th-2026-proposed-changes-to-grove-for-upcoming-spell/27761
        // Poll: https://vote.sky.money/polling/QmZRHXrp

        // Whitelist Grove spell with address 0x78e187473527938211187C85a414b19dD34ECD53 and codehash 0xa0162bcb9891a8c322c525502626282d5fc545bfb5ef2251b06c75f674af681f in GROVE_STARGUARD, direct execution: No
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
