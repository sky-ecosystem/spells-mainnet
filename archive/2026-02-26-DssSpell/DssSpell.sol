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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { VestAbstract } from "dss-interfaces/dss/VestAbstract.sol";
import { AllocatorSharedInstance, AllocatorIlkInstance } from "./dependencies/dss-allocator/AllocatorInstances.sol";
import { AllocatorInit, AllocatorIlkConfig } from "./dependencies/dss-allocator/AllocatorInit.sol";
import { StarGuardInit, StarGuardConfig } from "./dependencies/star-guard/StarGuardInit.sol";

interface LineMomLike {
    function addIlk(bytes32 ilk) external;
}

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256 amount);
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/f4c6fc80ce4bd80d8b92d4c15ba4c8a777cf7bc7/2026/executive-vote-2026-02-26-agent-6-and-7-onboarding.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-02-26 MakerDAO Executive Spell | Hash: 0xe6c1aa41d3fb26840ab8fa6cbc7e0248d17635c438843437659ab4e36fc7bb79";

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
    uint256 internal constant WAD     = 10 ** 18;
    uint256 internal constant RAY     = 10 ** 27;
    uint256 internal constant RAD     = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable MCD_JUG                    = DssExecLib.jug();
    address internal immutable MCD_VAT                    = DssExecLib.vat();
    address internal immutable MCD_VOW                    = DssExecLib.vow();
    address internal immutable DAI_USDS                   = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable DAI                        = DssExecLib.dai();
    address internal immutable SKY                        = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MCD_PAUSE_PROXY            = DssExecLib.pauseProxy();
    address internal immutable MCD_SPBEAM                 = DssExecLib.getChangelogAddress("MCD_SPBEAM");
    address internal immutable MCD_VEST_SKY_TREASURY      = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable ILK_REGISTRY               = DssExecLib.reg();
    address internal immutable LINE_MOM                   = DssExecLib.getChangelogAddress("LINE_MOM");
    address internal immutable CRON_STARGUARD_JOB         = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");
    address internal immutable CHAINLOG                   = DssExecLib.LOG;
    address internal immutable PIP_ALLOCATOR              = DssExecLib.getChangelogAddress("PIP_ALLOCATOR");
    address internal immutable ALLOCATOR_ROLES            = DssExecLib.getChangelogAddress("ALLOCATOR_ROLES");
    address internal immutable ALLOCATOR_REGISTRY         = DssExecLib.getChangelogAddress("ALLOCATOR_REGISTRY");
    address internal immutable ALLOCATOR_SPARK_A_VAULT    = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable SPARK_SUBPROXY             = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT    = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable GROVE_SUBPROXY             = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable ALLOCATOR_OBEX_A_VAULT     = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable OBEX_SUBPROXY              = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable REWARDS_DIST_LSSKY_SKY     = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable SPARK_STARGUARD            = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD            = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    address internal constant ALLOCATOR_PRYSM_A_VAULT     = 0x146181Aa9B362EaEC2eC3aDd7429a06D53B43d1a;
    address internal constant ALLOCATOR_PRYSM_A_BUFFER    = 0xD0BB61b34771146e31055f20f329cDf97429F889;
    address internal constant PRYSM_SUBPROXY              = 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3;
    address internal constant PRYSM_STARGUARD             = 0xBfA2D1dA838E55A74c61699e164cDFF8cF0cF0e2;
    address internal constant ALLOCATOR_INTERVAL_A_VAULT  = 0xDD3bE7650589E6A6171d454b026C4AD1a2C02720;
    address internal constant ALLOCATOR_INTERVAL_A_BUFFER = 0x67Ac5c8FbFDAc5265c995e9B2ACd830496438AfD;
    address internal constant INTERVAL_SUBPROXY           = 0x56a9bA5FE133EF4Ab1131E8ac7c4312a52284f5B;
    address internal constant INTERVAL_STARGUARD          = 0xB36e88c02E4619Ef34C0Db76C5BCb6655747FB28;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG   = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0xf655F6E7843685BfD8cfA4523d43F2b9922BBd77;
    bytes32 internal constant SPARK_SPELL_HASH = 0x56ca6d051fe05ba6a2b3f054aad61ce93e69542faf2ad02b9881bc1c03c8d2bf;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0xa2BDc0375Fc1C1343f7F6bf6c34c0263df1F0DB8;
    bytes32 internal constant GROVE_SPELL_HASH = 0x2b804a603fbbe25d00f8c19af41fc549b18131f51a30e3e73d1eea55fe994689;

    function actions() public override {
        // ---------- Launch Agent 6 Onboarding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-launch-agent-6-allocator-instance/27724
        // Poll: https://vote.sky.money/polling/QmQ95c8b

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // Note: Set sharedInstance with the following parameters:
        AllocatorSharedInstance memory allocatorSharedInstance = AllocatorSharedInstance({
            // sharedInstance.oracle: PIP_ALLOCATOR from chainlog
            oracle:   PIP_ALLOCATOR,
            // sharedInstance.roles: ALLOCATOR_ROLES from chainlog
            roles:    ALLOCATOR_ROLES,
            // sharedInstance.registry: ALLOCATOR_REGISTRY from chainlog
            registry: ALLOCATOR_REGISTRY
        });

        // Note: Set ilkInstance with the following parameters:
        AllocatorIlkInstance memory allocatorPrysmIlkInstance = AllocatorIlkInstance({
            // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog
            owner:  MCD_PAUSE_PROXY,
            // ilkInstance.vault: 0x146181Aa9B362EaEC2eC3aDd7429a06D53B43d1a (AllocatorVault contract)
            vault:  ALLOCATOR_PRYSM_A_VAULT,
            // ilkInstance.buffer: 0xD0BB61b34771146e31055f20f329cDf97429F889 (AllocatorBuffer contract)
            buffer: ALLOCATOR_PRYSM_A_BUFFER
        });

        // Note: Set cfg with the following parameters:
        AllocatorIlkConfig memory allocatorPrysmIlkCfg = AllocatorIlkConfig({
            // cfg.ilk: ALLOCATOR-PRYSM-A
            ilk:            "ALLOCATOR-PRYSM-A",
            // cfg.duty: 0
            duty:           ZERO_PCT_RATE,
            // cfg.gap: 10 million
            gap:            10_000_000 * RAD,
            // cfg.maxLine: 10 million
            maxLine:        10_000_000 * RAD,
            // cfg.ttl: 86,400 seconds
            ttl:            86_400,
            // cfg.AllocatorProxy: 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3
            allocatorProxy: PRYSM_SUBPROXY,
            // cfg.ilkRegistry: ILK_REGISTRY from chainlog
            ilkRegistry:    ILK_REGISTRY
        });

        // Note: We also need dss as an input parameter for initIlk
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Note: Now we can execute the initial instruction with all the relevant parameters by calling AllocatorInit.initIlk
        AllocatorInit.initIlk(dss, allocatorSharedInstance, allocatorPrysmIlkInstance, allocatorPrysmIlkCfg);

        // Remove newly created PIP_ALLOCATOR_PRYSM_A from chainlog
        // Note: PIP_ALLOCATOR_PRYSM_A was added to the chainlog when calling AllocatorInit.initIlk above
        ChainlogAbstract(DssExecLib.LOG).removeAddress("PIP_ALLOCATOR_PRYSM_A");

        // Add ALLOCATOR-PRYSM-A ilk to the LINE_MOM
        LineMomLike(LINE_MOM).addIlk("ALLOCATOR-PRYSM-A");

        // Add ALLOCATOR-PRYSM-A ilk to the SP-BEAM with the following parameters:
        // max: 3,000 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-PRYSM-A", "max", 3_000);

        // min: 0 bps
        // Note: min is not set as it is set to 0 bps by default

        // step: 400 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-PRYSM-A", "step", 400);

        // Init new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3
                subProxy: PRYSM_SUBPROXY,
                // cfg.subProxyKey: "PRYSM_SUBPROXY"
                subProxyKey: "PRYSM_SUBPROXY",
                // cfg.starGuard: 0xBfA2D1dA838E55A74c61699e164cDFF8cF0cF0e2
                starGuard: PRYSM_STARGUARD,
                // cfg.starGuardKey: "PRYSM_STARGUARD"
                starGuardKey: "PRYSM_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add PRYSM_STARGUARD module to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(PRYSM_STARGUARD);

        // ---------- Launch Agent 7 Onboarding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-launch-agent-7-allocator-instance/27725
        // Poll: https://vote.sky.money/polling/QmcxUENd

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // sharedInstance.oracle: PIP_ALLOCATOR from chainlog
        // sharedInstance.roles: ALLOCATOR_ROLES from chainlog
        // sharedInstance.registry: ALLOCATOR_REGISTRY from chainlog
        // Note: This was already set in the previous instruction as `allocatorSharedInstance`

        // Note: Set ilkInstance with the following parameters:
        AllocatorIlkInstance memory allocatorIntervalIlkInstance = AllocatorIlkInstance({
            // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog
            owner:  MCD_PAUSE_PROXY,
            // ilkInstance.vault: 0xDD3bE7650589E6A6171d454b026C4AD1a2C02720 (AllocatorVault contract)
            vault:  ALLOCATOR_INTERVAL_A_VAULT,
            // ilkInstance.buffer: 0x67Ac5c8FbFDAc5265c995e9B2ACd830496438AfD (AllocatorBuffer contract)
            buffer: ALLOCATOR_INTERVAL_A_BUFFER
        });

        // Note: Set cfg with the following parameters:
        AllocatorIlkConfig memory allocatorIntervalIlkCfg = AllocatorIlkConfig({
            // cfg.ilk: ALLOCATOR-INTERVAL-A
            ilk:            "ALLOCATOR-INTERVAL-A",
            // cfg.duty: 0
            duty:           ZERO_PCT_RATE,
            // cfg.gap: 10 million
            gap:            10_000_000 * RAD,
            // cfg.maxLine: 10 million
            maxLine:        10_000_000 * RAD,
            // cfg.ttl: 86,400 seconds
            ttl:            86_400,
            // cfg.AllocatorProxy: 0x56a9bA5FE133EF4Ab1131E8ac7c4312a52284f5B
            allocatorProxy: INTERVAL_SUBPROXY,
            // cfg.ilkRegistry: ILK_REGISTRY from chainlog
            ilkRegistry:    ILK_REGISTRY
        });

        // Note: Now we can execute the initial instruction with all the relevant parameters by calling AllocatorInit.initIlk
        AllocatorInit.initIlk(dss, allocatorSharedInstance, allocatorIntervalIlkInstance, allocatorIntervalIlkCfg);

        // Remove newly created PIP_ALLOCATOR_INTERVAL_A from chainlog
        // Note: PIP_ALLOCATOR_INTERVAL_A was added to the chainlog when calling AllocatorInit.initIlk above
        ChainlogAbstract(DssExecLib.LOG).removeAddress("PIP_ALLOCATOR_INTERVAL_A");

        // Add ALLOCATOR-INTERVAL-A ilk to the LINE_MOM
        LineMomLike(LINE_MOM).addIlk("ALLOCATOR-INTERVAL-A");

        // Add ALLOCATOR-INTERVAL-A ilk to the SP-BEAM with the following parameters:
        // max: 3,000 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-INTERVAL-A", "max", 3_000);

        // min: 0 bps
        // Note: min is not set as it is set to 0 bps by default

        // step: 400 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-INTERVAL-A", "step", 400);

        // Init new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x56a9bA5FE133EF4Ab1131E8ac7c4312a52284f5B
                subProxy: INTERVAL_SUBPROXY,
                // cfg.subProxyKey: "INTERVAL_SUBPROXY"
                subProxyKey: "INTERVAL_SUBPROXY",
                // cfg.starGuard: 0xB36e88c02E4619Ef34C0Db76C5BCb6655747FB28
                starGuard: INTERVAL_STARGUARD,
                // cfg.starGuardKey: "INTERVAL_STARGUARD"
                starGuardKey: "INTERVAL_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add INTERVAL_STARGUARD module to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(INTERVAL_STARGUARD);

        // Note: Bump chainlog patch version as new keys are being added
        DssExecLib.setChangelogVersion("1.20.12");

        // ---------- January 2026 MSC ----------
        // Forum: https://forum.sky.money/t/msc-5-settlement-summary-january-2026-spark-and-grove/27709/4
        // Atlas: https://sky-atlas.io/#A.2.4

        // Mint 8,079,210 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 8_079_210 * WAD);

        // Send 1,387,824 USDS from the Surplus Buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 1_387_824 * WAD);

        // Mint 6,205,320 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_205_320 * WAD);

        // Send 6,090 USDS from the Surplus Buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 6_090 * WAD);

        // Mint 2,095,775 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 2_095_775 * WAD);

        // Send 71,342 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 71_342 * WAD);

        // Transfer 4,808,248 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 4_808_248 * WAD);

        // Transfer 240,412 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3)
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 240_412 * WAD);

        // ---------- LSSKY->SKY Vesting Stream Adjustment ----------
        // Forum: https://forum.sky.money/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/2
        // Atlas: https://sky-atlas.io/#A.4.4.1.4.2.1.3.3
        // Forum: https://forum.sky.money/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/3

        // Call VestedRewardsDistribution.distribute() on REWARDS_DIST_LSSKY_SKY
        // Note: `distribute()` only needs to be called if it wasn't already, otherwise it reverts
        if (VestAbstract(MCD_VEST_SKY_TREASURY).unpaid(8) > 0) {
            VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SKY).distribute();
        }

        // MCD_VEST_SKY_TREASURY Vest Stream  | from: 'block.timestamp' | tau: 180 days | tot: 838,182,330 SKY | usr: REWARDS_DIST_LSSKY_SKY
        uint256 streamId = VestAbstract(MCD_VEST_SKY_TREASURY).create(
            REWARDS_DIST_LSSKY_SKY, // usr
            838_182_330 * WAD,      // tot
            block.timestamp,        // bgn
            180 days,               // tau
            0,                      // eta
            address(0)              // mgr
        );

        // res: 1 (restricted)
        VestAbstract(MCD_VEST_SKY_TREASURY).restrict(streamId);

        // Adjust the Sky allowance for MCD_VEST_SKY_TREASURY, reducing it by the remaining yanked stream amount and increasing it by the new stream total
        {
            // Note: Get the previous allowance
            uint256 pallowance = GemAbstract(SKY).allowance(address(this), MCD_VEST_SKY_TREASURY);
            // Note: Get the remaining allowance for the yanked stream
            uint256 ytot = VestAbstract(MCD_VEST_SKY_TREASURY).tot(8);
            uint256 yrxd = VestAbstract(MCD_VEST_SKY_TREASURY).rxd(8);
            uint256 yallowance = ytot - yrxd;
            // Note: Calculate the new allowance (previous allowance - remaining yanked stream amount + new stream total)
            uint256 allowance = pallowance - yallowance + 838_182_330 * WAD;
            // Note: Set the allowance
            GemAbstract(SKY).approve(MCD_VEST_SKY_TREASURY, allowance);
        }

        // Yank MCD_VEST_SKY_TREASURY vest with ID 8
        VestAbstract(MCD_VEST_SKY_TREASURY).yank(8);

        // File the new stream ID on REWARDS_DIST_LSSKY_SKY
        DssExecLib.setValue(REWARDS_DIST_LSSKY_SKY, "vestId", streamId);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-26-2026-proposed-changes-to-spark-for-upcoming-spell/27719
        // Atlas: https://sky-atlas.io/#A.2.8.2.2.2.5.5.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.4.2.3.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xdc1931c6f37149183ae2f15b61f56621d5091d1ce4469ad95cc6cdd33963db8c
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xf1a95e7ddaf2f95008608d7e27d8bed9ba6e9c7c55060e8e595f414d88e6b5c9
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x29be63afc3b7495581259401c68e6dd892e0a8870a45ad66b2d7b224f4b33dde

        // Whitelist Spark spell with address 0xf655F6E7843685BfD8cfA4523d43F2b9922BBd77 and codehash 0x56ca6d051fe05ba6a2b3f054aad61ce93e69542faf2ad02b9881bc1c03c8d2bf in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.sky.money/t/february-26-2026-proposed-changes-to-grove-for-upcoming-spell/27712
        // Poll: https://vote.sky.money/polling/QmcxUENd

        // Whitelist Grove spell with address 0xa2BDc0375Fc1C1343f7F6bf6c34c0263df1F0DB8 and codehash 0x2b804a603fbbe25d00f8c19af41fc549b18131f51a30e3e73d1eea55fe994689 in GROVE_STARGUARD, direct execution: No
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
