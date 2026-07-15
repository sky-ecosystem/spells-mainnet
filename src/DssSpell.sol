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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";
import { RwaLiquidationOracleAbstract } from "dss-interfaces/dss/mip21/RwaLiquidationOracleAbstract.sol";

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
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/485978fd341c182f8a35335f283d57fcd3cb8df0/2026/executive-vote-2026-07-16-june-msc-staking-rewards-normalization.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-07-16 MakerDAO Executive Spell | Hash: 0xbdc3ac0fda8f93fbcddb6eb7907ec6cb6dd68652c8aa85fd1960191918408f78";

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
    address internal immutable MCD_VAT                        = DssExecLib.vat();
    address internal immutable MCD_JUG                        = DssExecLib.jug();
    address internal immutable MCD_VOW                        = DssExecLib.vow();
    address internal immutable DAI                            = DssExecLib.dai();
    address internal immutable DAI_USDS                       = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_LITE_PSM_USDC_A            = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable ALLOCATOR_SPARK_A_VAULT        = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable SPARK_SUBPROXY                 = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT        = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable GROVE_SUBPROXY                 = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY                  = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable ALLOCATOR_OBEX_A_VAULT         = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable OBEX_SUBPROXY                  = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY               = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable REWARDS_DIST_LSSKY_SKY         = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable RWA001_A_URN                   = DssExecLib.getChangelogAddress("RWA001_A_URN");
    address internal immutable MIP21_LIQUIDATION_ORACLE       = DssExecLib.getChangelogAddress("MIP21_LIQUIDATION_ORACLE");
    address internal immutable SPARK_STARGUARD                = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD                = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable PRYSM_STARGUARD                = DssExecLib.getChangelogAddress("PRYSM_STARGUARD");
    address internal immutable SAFE_HARBOR_AGREEMENT          = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");

    address internal constant OSERO_ALM_PROXY                 = 0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884;
    address internal constant EMSP_STUSDS_RATE_S_DISS_BUD_FAB = 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1;
    address internal constant EMSP_STUSDS_WIPE_PARAM_FAB      = 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096;
    address internal constant EMSP_STUSDS_RATE_SETTER_HALT    = 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb;

    // ---------- Wallets ----------
    address internal constant DEMAND_SIDE_BUFFER_MULTISIG  = 0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0xC1090e8fEE666868622a2F1e870185F944108Ee2;
    bytes32 internal constant SPARK_SPELL_HASH = 0xa7b0b6c470169f40016d354a8944f9e5f3f787159fec5192694e8f1ddbc7f26f;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0x4f1318bC0490dC7C7F8230F1dd91A4A2e4694134;
    bytes32 internal constant GROVE_SPELL_HASH = 0x38dd6399490f19d7a7e17a6eafda5d2ad92f9395c08efe2fdbacfda3b6d36a89;

    // ---------- Osero Spell ----------
    address internal constant OSERO_SPELL      = 0x5D9311fcDda62c08EB9F1115Ca804881a6660445;
    bytes32 internal constant OSERO_SPELL_HASH = 0x7dca6bc3a3097897198698a674bc824fd3bbb1c9b94c655cd0d78c49db2b9f3e;

    function actions() public override {
        // ---------- Monthly Settlement Cycle for June 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-10-settlement-summary-june-2026/28038
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 16,923,682 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_923_682 * WAD);

        // Send 9,746,443 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 9_746_443 * WAD);

        // Mint 12,342,158 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 12_342_158 * WAD);

        // Send 2,328,332 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 2_328_332 * WAD);

        // Send 34,902 USDS from the surplus buffer to the Demand-side Buffer (0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B)
        _transferUsds(DEMAND_SIDE_BUFFER_MULTISIG, 34_902 * WAD);

        // Send 77,284 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 77_284 * WAD);

        // Mint 3,450,783 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 3_450_783 * WAD);

        // Send 1,519,539 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 1_519_539 * WAD);

        // Send 204,242 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 204_242 * WAD);

        // Send 3,378,069 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_378_069 * WAD);

        // ---------- LSSKY->SKY Rewards Normalization ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/26
        // Atlas: https://sky-atlas.io/#a98a1bfe-5713-43f5-a8bd-83c5808900b8

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 286,714,697 SKY
            vestTot: 286_714_697 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- RWA001-A Offboarding Spell 2 ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-rwa001-a-offboarding/27706/5
        // Forum: https://forum.skyeco.com/t/technical-scope-of-rwa001-a-offboarding/27706/16

        // Call MIP21_LIQUIDATION_ORACLE.cull with:
        // MIP21_LIQUIDATION_ORACLE being 0x88f88Bb9E66241B73B84f3A6E197FbBa487b1E30
        RwaLiquidationOracleAbstract(MIP21_LIQUIDATION_ORACLE).cull(
            // bytes32 ilk being "RWA001-A"
            "RWA001-A",
            // address urn being RWA001_A_URN
            RWA001_A_URN
        );

        // ---------- Add STUSDS_MOM Emergency Spells to the Chainlog ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967/5
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967/7

        // Add the following Emergency Spells related to the STUSDS_MOM to the chainlog:
        // EMSP_STUSDS_RATE_S_DISS_BUD_FAB: 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1
        DssExecLib.setChangelogAddress("EMSP_STUSDS_RATE_S_DISS_BUD_FAB", EMSP_STUSDS_RATE_S_DISS_BUD_FAB);

        // EMSP_STUSDS_WIPE_PARAM_FAB: 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096
        DssExecLib.setChangelogAddress("EMSP_STUSDS_WIPE_PARAM_FAB", EMSP_STUSDS_WIPE_PARAM_FAB);

        // EMSP_STUSDS_RATE_SETTER_HALT: 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb
        DssExecLib.setChangelogAddress("EMSP_STUSDS_RATE_SETTER_HALT", EMSP_STUSDS_RATE_SETTER_HALT);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.18");

        // ---------- Whitelist Osero DPAU ALMProxy on LitePSM ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist the Osero ALMProxy at 0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884 on Sky LitePSM (MCD_LITE_PSM_USDC_A) via kiss
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(OSERO_ALM_PROXY);

        // ---------- Adjust Osero DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Note: use DssExecLib.setIlkAutoLineParameters() to update multiple ALLOCATOR-PRYSM-A DC-IAM parameters at the same time:
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PRYSM-A",
            // Decrease ALLOCATOR-PRYSM-A `maxLine` from 10 million USDS to 5 million USDS
            _amount: 5 * MILLION,
            // Decrease ALLOCATOR-PRYSM-A `gap` from 10 million USDS to 1 million USDS
            _gap: 1 * MILLION,
            // Leave ALLOCATOR-PRYSM-A `duty` and `ttl` unchanged at 0% and 24 hours (86,400 seconds) respectively
            _ttl: 86_400 seconds
            // Note: This operation does not modify `duty`, as this function does not support updating it.
        });

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:1 chain: 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1, 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096, 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078623346643832374635383938396346616346453530643246386538364131313133623630363644310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078373638443543653633396337453764353145313234344532363334643631343962643064383039360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783931383038414265436438323439356134613762663237643830433863316538396465396566666200000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-spark-for-upcoming-spell/28029
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Atlas: https://sky-atlas.io/#8dd2eb27-a760-4287-89cf-7b5bdb0c5d7c
        // Atlas: https://sky-atlas.io/#6a4870fa-73f1-4d49-b7ee-d531fb59a971
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xd177bc28b65afb23dc39a5e7cfdded7084b3b722b230e08d7067b68fa0f4486a
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xdde478db4ba5882a5d48d19fdbae057fd703688e4f1e16fb673407fc08476a9f
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf99372ccca4b99dd04dc0ddb038e949b62f4d25810b0203572dc90bce025e805
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x2df281a276e0c17eff9a05e65bfc05937c2f600edec1a82386a6efb6dbe9d63d
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x3cb4165f1357d553445b0de790e4e8b4a71358f42f39d35f7de51b308ade558c
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x451bb53f80ad2906ff06cc3d03c88a6b09f350db371c4782e0621e26a1d55a43

        // Whitelist Spark spell with address 0xC1090e8fEE666868622a2F1e870185F944108Ee2 and codehash 0xa7b0b6c470169f40016d354a8944f9e5f3f787159fec5192694e8f1ddbc7f26f in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist Grove spell with address 0x4f1318bC0490dC7C7F8230F1dd91A4A2e4694134 and codehash 0x38dd6399490f19d7a7e17a6eafda5d2ad92f9395c08efe2fdbacfda3b6d36a89 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist Osero spell with address 0x5D9311fcDda62c08EB9F1115Ca804881a6660445 and codehash 0x7dca6bc3a3097897198698a674bc824fd3bbb1c9b94c655cd0d78c49db2b9f3e in PRYSM_STARGUARD, direct execution: No
        StarGuardLike(PRYSM_STARGUARD).plot(OSERO_SPELL, OSERO_SPELL_HASH);
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
