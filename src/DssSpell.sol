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
import { DssInstance, MCD } from "dss-test/MCD.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";
// Copied from https://github.com/sky-ecosystem/dss-flappers/blob/655d2dd2c7000235633fec87b763ee0143e85bab/deploy/FlapperInit.sol
import { FlapperInit, SBEBeamConfig } from "src/dependencies/dss-flappers/FlapperInit.sol";
// Copied from https://github.com/sky-ecosystem/endgame-toolkit/blob/4f238f9b23298190150d49482bad56c00f0af825/script/dependencies/treasury-funded-farms/TreasuryFundedFarmingInit.sol
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface StakingRewardsLike {
    function setRewardsDuration(uint256 _rewardsDuration) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/c75f59295640fe8bd53ae87d4bbdd032e24f2c35/2026/executive-vote-2026-08-13-initialize-sbe-beam.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-08-13 MakerDAO Executive Spell | Hash: 0xa924d6b2502d15cd95ffd5bb3f910e0de7d30c1d6ee675bbd002ebeed6f805be";

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
    uint256 internal constant RAD     = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                 = DssExecLib.vat();
    address internal immutable MCD_JUG                 = DssExecLib.jug();
    address internal immutable MCD_VOW                 = DssExecLib.vow();
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_SPLIT               = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable SPARK_SUBPROXY          = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable GROVE_SUBPROXY          = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY           = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable ALLOCATOR_OBEX_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable OBEX_SUBPROXY           = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY        = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable ALLOCATOR_PRYSM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_PRYSM_A_VAULT");
    address internal immutable REWARDS_DIST_LSSKY_SKY  = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable PRYSM_SUBPROXY          = DssExecLib.getChangelogAddress("PRYSM_SUBPROXY");
    address internal immutable PRYSM_STARGUARD         = DssExecLib.getChangelogAddress("PRYSM_STARGUARD");
    address internal immutable SPARK_STARGUARD         = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD         = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable SAFE_HARBOR_AGREEMENT   = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");
    address internal immutable MCD_IAM_AUTO_LINE       = DssExecLib.getChangelogAddress("MCD_IAM_AUTO_LINE");

    address internal constant OWNER_REWARDS_LSSKY_USDS = 0xA3d3A2e9Fe5d0901D720D5382E4a7eA12D4E2b0e;
    address internal constant MCD_SBEBEAM              = 0xc8b61d211D3D03A630Fb09199E17953a8c9749a9;

    // ---------- Wallets ----------
    address internal constant MCD_SBEBEAM_BUD              = 0x869294B42B80f99CF3Bdac0F44abddAd6cD41330;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0xc827237CB91Fa8E78B8dfA4F77838eDf924C04e9;
    bytes32 internal constant SPARK_SPELL_HASH = 0x74f56d9a7a918f0410aaf2ecf9ec9023970ec01acb3f83f4f14633a6ffd3454b;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0xb12C687188427d7D1E5253afA5f09A101Fbd9d4b;
    bytes32 internal constant GROVE_SPELL_HASH = 0x180fc2de506150de525027a135843e91123578dc1f03945b69a489dce863f85c;

    function actions() public override {
        // ---------- Initialize SBE BEAM ----------
        // Forum: https://forum.skyeco.com/t/smart-burn-engine-bounded-external-access-module-sbe-beam-launch/28149
        // Poll: https://vote.sky.money/polling/QmcVdr3p

        // Note: We need a DssInstance as an input parameter for initFarmOwner
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Call FlapperInit.initFarmOwner with:
        FlapperInit.initFarmOwner(
            // Note: Use DssInstance initialised above
            dss,
            // address farmOwner: 0xA3d3A2e9Fe5d0901D720D5382E4a7eA12D4E2b0e
            OWNER_REWARDS_LSSKY_USDS,
            // bytes32 chainlogKey: OWNER_REWARDS_LSSKY_USDS
            "OWNER_REWARDS_LSSKY_USDS"
        );

        // Note: We need to declare an array of buds for SBEBeam config
        address[] memory buds = new address[](1);
        buds[0] = MCD_SBEBEAM_BUD;

        // Call FlapperInit.initSBEBeam with:
        FlapperInit.initSBEBeam(
            // Note: Use DssInstance initialised above
            dss,
            // address beam: 0xc8b61d211D3D03A630Fb09199E17953a8c9749a9
            MCD_SBEBEAM,
            // address farmOwner: 0xA3d3A2e9Fe5d0901D720D5382E4a7eA12D4E2b0e
            OWNER_REWARDS_LSSKY_USDS,
            SBEBeamConfig({
                // uint256 cfg.maxKbump: 12,000 USDS
                maxKbump: 12_000 * RAD,
                // uint256 cfg.minHop: 550 seconds
                minHop: 550 seconds,
                // uint256 cfg.maxRate: 350 million USDS per year
                maxRate: 350 * MILLION * RAD / 365 days,
                // uint256 cfg.tau: 30 minutes
                tau: 30 minutes,
                // address[] cfg.buds: 0x869294B42B80f99CF3Bdac0F44abddAd6cD41330
                buds: buds,
                // bytes32 cfg.chainlogKey: MCD_SBEBEAM
                chainlogKey: "MCD_SBEBEAM"
            })
        );

        // ---------- Monthly Settlement Cycle for July 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-11-settlement-summary-july-2026/28151
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 9,465,419 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 9_465_419 * WAD);

        // Send 4,442,924 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 4_442_924 * WAD);

        // Mint 9,685,438 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 9_685_438 * WAD);

        // Send 1,808,084 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 1_808_084 * WAD);

        // Send 35,328 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 35_328 * WAD);

        // Mint 2,535,968 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 2_535_968 * WAD);

        // Send 916,736 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 916_736 * WAD);

        // Send 327,407 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 327_407 * WAD);

        // Mint 497 USDS debt in ALLOCATOR-PRYSM-A and transfer the amount to the surplus buffer
        _takeAllocatorPayment(ALLOCATOR_PRYSM_A_VAULT, 497 * WAD);

        // Send 12,043 USDS from the surplus buffer to the PRYSM_SUBPROXY
        _transferUsds(PRYSM_SUBPROXY, 12_043 * WAD);

        // Send 2,103,484 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 2_103_484 * WAD);

        // ---------- LSSKY->SKY Rewards Normalization ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/2
        // Atlas: https://sky-atlas.io/#7932c8f3-ce44-49ea-adc4-f6391c621c6e

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 96,903,706 SKY
            vestTot: 96_903_706 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- Increase Buybacks and Reactivate LSSKY->USDS Farm ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/2
        // Atlas: https://sky-atlas.io/#7932c8f3-ce44-49ea-adc4-f6391c621c6e

        // Decrease splitter.hop by 10,039 seconds from 13,787 seconds to 3,748 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 3_748);

        // Decrease rewardsDuration in REWARDS_LSSKY_USDS by 10,039 seconds from 13,787 seconds to 3,748 seconds
        // Note: REWARDS_LSSKY_USDS ownership was transferred to OWNER_REWARDS_LSSKY_USDS above, so this has to be routed through the FarmOwner
        StakingRewardsLike(OWNER_REWARDS_LSSKY_USDS).setRewardsDuration(3_748);

        // Decrease splitter.burn by 45 percentage points from 100% to 55%
        DssExecLib.setValue(MCD_SPLIT, "burn", 55 * WAD / 100);

        // Keep kicker.kbump at 6,000 USDS
        // Note: No action required as value did not change

        // ---------- Adjust ALLOCATOR-GROVE-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/august-13-2026-proposed-changes-to-grove-for-upcoming-spell/28126
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase ALLOCATOR-GROVE-A line by 5 million USDS from 5 million USDS to 10 million USDS
        // Increase ALLOCATOR-GROVE-A gap by 1 million USDS from 1 million USDS to 2 million USDS
        // Leave ALLOCATOR-GROVE-A ttl unchanged at 86,400 seconds
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-GROVE-A",
            _amount: 10 * MILLION,
            _gap: 2 * MILLION,
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-GROVE-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-GROVE-A");

        // ---------- Adjust ALLOCATOR-PRYSM-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/osero-requested-changes-to-allocator-vault-parameters/28147
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase ALLOCATOR-PRYSM-A line by 5 million USDS from 5 million USDS to 10 million USDS
        // Increase ALLOCATOR-PRYSM-A gap by 1 million USDS from 1 million USDS to 2 million USDS
        // Leave ALLOCATOR-PRYSM-A ttl unchanged at 86,400 seconds
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PRYSM-A",
            _amount: 10 * MILLION,
            _gap: 2 * MILLION,
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-PRYSM-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-PRYSM-A");

        // ---------- Rename Chainlog Keys for Osero ----------
        // Forum: https://forum.skyeco.com/t/proposed-housekeeping-item-2026-08-13-executive-vote/28148
        // Atlas: https://sky-atlas.io/#0d0e2e1a-0502-4ee3-bc9d-8bd8ddde19ec

        // Rename PRYSM_STARGUARD to OSERO_STARGUARD in the chainlog
        dss.chainlog.removeAddress("PRYSM_STARGUARD");
        DssExecLib.setChangelogAddress("OSERO_STARGUARD", PRYSM_STARGUARD);

        // Rename PRYSM_SUBPROXY to OSERO_SUBPROXY in the chainlog
        dss.chainlog.removeAddress("PRYSM_SUBPROXY");
        DssExecLib.setChangelogAddress("OSERO_SUBPROXY", PRYSM_SUBPROXY);

        // Note: bump chainlog version
        DssExecLib.setChangelogVersion("1.20.19");

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:1 chain: 0xc8b61d211D3D03A630Fb09199E17953a8c9749a9, 0xA3d3A2e9Fe5d0901D720D5382E4a7eA12D4E2b0e
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078633862363164323131443344303341363330466230393139394531373935336138633937343961390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30784133643341326539466535643039303144373230443533383245346137654131324434453262306500000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-13-2026-proposed-changes-to-spark-for-upcoming-spell/28135
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x101ed4ff7ef77f8e4a6db6af4bbf053b703001c0245a1e166babb8ba6ad633fb
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf99d50e34900ea8f54c90053584f758d2a6d1ddbbe77a8c8d751e2c5a8fd0493
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x3240fc78276a2f4898188809464b3357124b2c42065f55a46a7a7254eabd0f82
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Atlas: https://sky-atlas.io/#6a4870fa-73f1-4d49-b7ee-d531fb59a971

        // Whitelist Spark spell with address 0xc827237CB91Fa8E78B8dfA4F77838eDf924C04e9 and codehash 0x74f56d9a7a918f0410aaf2ecf9ec9023970ec01acb3f83f4f14633a6ffd3454b in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-13-2026-proposed-changes-to-grove-for-upcoming-spell/28126
        // Poll: https://snapshot.org/#/s:grovefinance.eth/proposal/0x180c2e7ea0dea1649d9d73dcc7bb53e0be9896e0a750ac10cbba1dc352487d8d
        // Poll: https://snapshot.org/#/s:grovefinance.eth/proposal/0x3bce0bdda59ea54dd6056e772aa7f77880209b0206d11a7345286136d28fba70
        // Poll: https://snapshot.org/#/s:grovefinance.eth/proposal/0x65fa0cfa74a7831c956d87e53dee5f1f6f5950690b9590a040180bff4a0388b9

        // Whitelist Grove spell with address 0xb12C687188427d7D1E5253afA5f09A101Fbd9d4b and codehash 0x180fc2de506150de525027a135843e91123578dc1f03945b69a489dce863f85c in GROVE_STARGUARD, direct execution: No
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
