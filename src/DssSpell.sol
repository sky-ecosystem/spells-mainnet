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
import { DssInstance, MCD } from "dss-test/MCD.sol";
import { ChainlogAbstract } from "dss-interfaces/dss/ChainlogAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/MakerDAO/ChainSecurity_MakerDAO_AllocatorDeploymentScripts_Audit.pdf)
import { AllocatorSharedInstance, AllocatorIlkInstance } from "./dependencies/dss-allocator/AllocatorInstances.sol";
import { AllocatorInit, AllocatorIlkConfig } from "./dependencies/dss-allocator/AllocatorInit.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_SkyStUSDS_Audit.pdf)
import { StUsdsInit } from "./dependencies/stusds/StUsdsInit.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface LineMomLike {
    function addIlk(bytes32 ilk) external;
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
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-06-18 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant ZERO_PCT_RATE = 1000000000000000000000000000;

    // ---------- Math ----------
    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;
    uint256 internal constant RAD = 10 ** 45;

    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant BILLION = 10 ** 9;

    // ---------- Contracts ----------
    address internal immutable MCD_PAUSE_PROXY = DssExecLib.pauseProxy();
    address internal immutable PIP_ALLOCATOR = DssExecLib.getChangelogAddress("PIP_ALLOCATOR");
    address internal immutable ALLOCATOR_ROLES = DssExecLib.getChangelogAddress("ALLOCATOR_ROLES");
    address internal immutable ALLOCATOR_REGISTRY = DssExecLib.getChangelogAddress("ALLOCATOR_REGISTRY");
    address internal immutable GROVE_SUBPROXY = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable ILK_REGISTRY = DssExecLib.getChangelogAddress("ILK_REGISTRY");
    address internal immutable LINE_MOM = DssExecLib.getChangelogAddress("LINE_MOM");
    address internal immutable MCD_SPBEAM = DssExecLib.getChangelogAddress("MCD_SPBEAM");
    address internal immutable CHAINLOG = DssExecLib.LOG;
    address internal immutable MCD_LITE_PSM_USDC_A = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable DAI_USDS = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SPARK_SUBPROXY = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable KEEL_SUBPROXY = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable OBEX_SUBPROXY = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable DAI = DssExecLib.dai();
    address internal immutable MCD_JUG = DssExecLib.jug();
    address internal immutable MCD_VAT = DssExecLib.vat();
    address internal immutable MCD_VOW = DssExecLib.vow();
    address internal immutable REWARDS_DIST_LSSKY_SKY = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable SPARK_STARGUARD = DssExecLib.getChangelogAddress("SPARK_STARGUARD");

    address internal constant ALLOCATOR_GROVE_A_VAULT = 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB;
    address internal constant ALLOCATOR_GROVE_A_BUFFER = 0x436DABce608f73BeA2b75fba35bffe72739697d5;

    address internal constant NEW_STUSDS_MOM = 0x99159d0b885CC6633daC7CD4d82e4247A834b89A;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL = 0xe08BD6D9016EAC522903FC68c80F809664C2692A;
    bytes32 internal constant SPARK_SPELL_HASH = 0xdf7cca8d640cde5f2f8184ccb03f76031a024cb8ab2c192092acfe329b5aebf5;

    function actions() public override {
        // ---------- ALLOCATOR-GROVE-A Onboarding ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-allocator-instance-for-grove/27966
        // Poll: https://vote.sky.money/polling/QmdYpnYS

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // Note: Set sharedInstance with the following parameters:
        AllocatorSharedInstance memory allocatorSharedInstance = AllocatorSharedInstance({
            // sharedInstance.oracle being PIP_ALLOCATOR from chainlog
            oracle: PIP_ALLOCATOR,
            // sharedInstance.roles being ALLOCATOR_ROLES from chainlog
            roles: ALLOCATOR_ROLES,
            // sharedInstance.registry being ALLOCATOR_REGISTRY from chainlog
            registry: ALLOCATOR_REGISTRY
        });

        // Note: Set ilkInstance with the following parameters:
        AllocatorIlkInstance memory allocatorIlkInstance = AllocatorIlkInstance({
            // ilkInstance.owner being MCD_PAUSE_PROXY from chainlog
            owner: MCD_PAUSE_PROXY,
            // ilkInstance.vault being 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB
            vault: ALLOCATOR_GROVE_A_VAULT,
            // ilkInstance.buffer being 0x436DABce608f73BeA2b75fba35bffe72739697d5
            buffer: ALLOCATOR_GROVE_A_BUFFER
        });

        // Note: Set cfg with the following parameters:
        AllocatorIlkConfig memory allocatorGroveIlkCfg = AllocatorIlkConfig({
            // cfg.ilk being ALLOCATOR-GROVE-A
            ilk: "ALLOCATOR-GROVE-A",
            // cfg.duty being 0%
            duty: ZERO_PCT_RATE,
            // cfg.gap being 1 million USDS
            gap: 1_000_000 * RAD,
            // cfg.maxLine being 5 million USDS
            maxLine: 5_000_000 * RAD,
            // cfg.ttl being 86,400 seconds
            ttl: 86_400,
            // cfg.allocatorProxy being 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba
            allocatorProxy: GROVE_SUBPROXY,
            // cfg.ilkRegistry being ILK_REGISTRY from chainlog
            ilkRegistry: ILK_REGISTRY
        });

        // Note: We also need dss as an input parameter for initIlk
        DssInstance memory dss = MCD.loadFromChainlog(CHAINLOG);

        // Note: Call AllocatorInit.initIlk with the parameters created above:
        AllocatorInit.initIlk(dss, allocatorSharedInstance, allocatorIlkInstance, allocatorGroveIlkCfg);

        // Remove the newly created PIP_ALLOCATOR_GROVE_A from chainlog
        // Note: PIP_ALLOCATOR_GROVE_A was added to the chainlog when calling AllocatorInit.initIlk above
        ChainlogAbstract(CHAINLOG).removeAddress("PIP_ALLOCATOR_GROVE_A");

        // Add ALLOCATOR-GROVE-A ilk to the LINE_MOM
        LineMomLike(LINE_MOM).addIlk("ALLOCATOR-GROVE-A");

        // Add ALLOCATOR-GROVE-A ilk to the MCD_SPBEAM with the following parameters:

        // max being 3,000 basis points
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-GROVE-A", "max", 3_000);

        // min being 0 basis points
        // Note: min is not set as it is set to 0 basis points by default

        // step being 400 basis points
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-GROVE-A", "step", 400);

        // ---------- LitePSM Parameter Update ----------
        // Forum: https://forum.skyeco.com/t/lite-psm-usdc-a-parameter-change/27961
        // Forum: https://forum.skyeco.com/t/lite-psm-usdc-a-parameter-change/27961/2
        // Atlas: https://sky-atlas.io/#8694e11a-6acd-43f1-90fd-67eb7e7d98d6

        // Increase LITE-PSM-USDC-A `buf` by 400 million DAI from 400 million DAI to 800 million DAI
        DssExecLib.setValue(MCD_LITE_PSM_USDC_A, "buf", 800 * MILLION * WAD);

        // Increase LITE-PSM-USDC-A `gap` by 400 million DAI from 400 million DAI to 800 million DAI
        // Note: Keep the same values for unchanged parameters (maxLine and ttl)
        DssExecLib.setIlkAutoLineParameters("LITE-PSM-USDC-A", 10 * BILLION, 800 * MILLION, 12 hours);

        // ---------- stUSDS MOM Replacement ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967/4

        // Activate new STUSDS_MOM at 0x99159d0b885CC6633daC7CD4d82e4247A834b89A
        StUsdsInit.replaceMom(dss, NEW_STUSDS_MOM);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.16");

        // ---------- Monthly Settlement Cycle for May 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-9-settlement-summary-may-2026/27962
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 13,427,874 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 13_427_874 * WAD);

        // Send 4,204,857 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 4_204_857 * WAD);

        // Mint 8,877,823 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 8_877_823 * WAD);

        // Send 271,843 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 271_843 * WAD);

        // Send 32,279 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 32_279 * WAD);

        // Mint 2,461,845 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 2_461_845 * WAD);

        // Send 526,204 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 526_204 * WAD);

        // Send 1,806,616 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 1_806_616 * WAD);

        // Transfer 2,946,125 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 2_946_125 * WAD);

        // ---------- LSSKY-> SKY Rewards Normalization ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/24
        // Atlas: https://sky-atlas.io/#6cacdc1c-bdfa-4f68-bdb4-bf31943dcfba

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 240,862,942 SKY
            vestTot: 240_862_942 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- Safe Harbor Update (TODO) ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // TBD after technical scopes published

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/june-18-2026-proposed-changes-to-spark-for-upcoming-spell/27952
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xe556733096975218413695c0bd3905a865a38e4ded7603551b40f49cebfbb9ba
        // Poll: https://vote.sky.money/polling/QmdYpnYS
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x81e46a9c323dafde20fa6104fb93855889217b590335157c3c58be6760735747

        // Whitelist Spark spell with address 0xe08BD6D9016EAC522903FC68c80F809664C2692A and codehash 0xdf7cca8d640cde5f2f8184ccb03f76031a024cb8ab2c192092acfe329b5aebf5 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);
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
