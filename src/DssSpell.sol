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
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { ChainlogAbstract } from "dss-interfaces/dss/ChainlogAbstract.sol";
import { DssInstance, MCD } from "dss-test/MCD.sol";
import { AllocatorSharedInstance, AllocatorIlkInstance } from "./dependencies/dss-allocator/AllocatorInstances.sol";
import { AllocatorInit, AllocatorIlkConfig } from "./dependencies/dss-allocator/AllocatorInit.sol";
import { StarGuardInit, StarGuardConfig } from "src/dependencies/star-guard/StarGuardInit.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface LineMomLike {
    function addIlk(bytes32 ilk) external;
}

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-01-29 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // Note: by the previous convention it should be a comma-separated list of DAO resolutions IPFS hashes
    string public constant dao_resolutions = "bafkreiczdjq55zsxvxcf4le3oaqvhp4jgvls4n4b7xbnzvkwilzen3a2te";

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
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;
    uint256 internal constant RAY     = 10 ** 27;
    uint256 internal constant RAD     = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable CHAINLOG                = DssExecLib.LOG;
    address internal immutable DAI                     = DssExecLib.dai();
    address internal immutable MCD_VAT                 = DssExecLib.vat();
    address internal immutable MCD_JUG                 = DssExecLib.jug();
    address internal immutable MCD_VOW                 = DssExecLib.vow();
    address internal immutable MCD_SPBEAM              = DssExecLib.getChangelogAddress("MCD_SPBEAM");
    address internal immutable DAI_USDS                = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_PAUSE_PROXY         = DssExecLib.pauseProxy();
    address internal immutable ILK_REGISTRY            = DssExecLib.reg();
    address internal immutable PIP_ALLOCATOR           = DssExecLib.getChangelogAddress("PIP_ALLOCATOR");
    address internal immutable ALLOCATOR_ROLES         = DssExecLib.getChangelogAddress("ALLOCATOR_ROLES");
    address internal immutable ALLOCATOR_REGISTRY      = DssExecLib.getChangelogAddress("ALLOCATOR_REGISTRY");
    address internal immutable LINE_MOM                = DssExecLib.getChangelogAddress("LINE_MOM");
    address internal immutable ALLOCATOR_SPARK_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable CRON_STARGUARD_JOB      = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");
    address internal immutable SPARK_SUBPROXY          = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable OBEX_SUBPROXY           = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SPARK_STARGUARD         = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD         = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    address internal constant ALLOCATOR_PATTERN_A_VAULT    = 0xbd34fc6AAa1d3F52B314CB9D78023dd23eAc3B0E;
    address internal constant ALLOCATOR_PATTERN_A_BUFFER   = 0x823459b55D79F0421f24a4828237F7ecb8D7F1ef;
    address internal constant ALLOCATOR_PATTERN_A_SUBPROXY = 0xbC8959Ae2d4E9B385Fe620BEF48C2FD7f4A84736;
    address internal constant PATTERN_STARGUARD            = 0x2fb18b28fB39Ec3b26C3B5AF5222e2ca3B8B2269;
    address internal constant SKYBASE_SUBPROXY             = 0x08978E3700859E476201c1D7438B3427e3C81140;
    address internal constant SKYBASE_STARGUARD            = 0xA170086AeF9b3b81dD73897A0dF56B55e4C2a1F7;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG   = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;
    address internal constant USDS_DEMAND_SUBSIDIES_MULTISIG = 0x3F32bC09d41eE699844F8296e806417D6bf61Bba;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0xa091BeD493C27efaa4D6e06e32684eCa0325adcA;
    bytes32 internal constant SPARK_SPELL_HASH = 0x6ef4bf2258afab1e1c857892e5253e95880230a86ee9adc773fab559d7a594ec;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_SPELL      = 0x67aB5b15E3907E3631a303c50060c2207465a9AD;
    bytes32 internal constant GROVE_SPELL_HASH = 0x7e4eb1e46f50b347fc7c8d20face6070c8fda4876049e32f3877a89cede1d533;

    function actions() public override {
        // ---------- Monthly Settlement Cycle and Treasury Management Function for November and December ----------
        // Forum: https://forum.sky.money/t/msc-4-settlement-summary-november-and-december-2025-spark-grove/27617/5
        // Atlas: https://sky-atlas.io/#A.2.4
        // Atlas: https://sky-atlas.io/#A.2.3.1.4.1.1
        // Atlas: https://sky-atlas.io/#A.2.3.1.4.1.2

        // Mint 25,547,255 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 25_547_255 * WAD);

        // Transfer 7,071,339 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 7_071_339 * WAD);

        // Mint 14,311,822 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 14_311_822 * WAD);

        // Mint 1,768,819 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the Surplus Buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_768_819 * WAD);

        // Transfer 442,327 USDS from the Surplus Buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 442_327 * WAD);

        // Transfer 6,632,421 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364).
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 6_632_421 * WAD);

        // Transfer 331,620 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3).
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 331_620 * WAD);

        // ---------- Pattern Onboarding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-pattern-allocator-instance/27641

        // Init new Allocator instance by calling AllocatorInit.initIlk with:
        // Note: Set sharedInstance with the following parameters:
        AllocatorSharedInstance memory allocatorSharedInstance = AllocatorSharedInstance({
            // sharedInstance.oracle: PIP_ALLOCATOR from chainlog
            oracle:   PIP_ALLOCATOR,
            // sharedInstance.roles: ALLOCATOR_ROLES from chainlog
            roles:    ALLOCATOR_ROLES,
            // sharedInstance: ALLOCATOR_REGISTRY from chainlog
            registry: ALLOCATOR_REGISTRY
        });

        // Note: Set ilkInstance with the following parameters:
        AllocatorIlkInstance memory allocatorIlkInstance = AllocatorIlkInstance({
            // ilkInstance.owner: MCD_PAUSE_PROXY from chainlog
            owner:  MCD_PAUSE_PROXY,
            // ilkInstance.vault: 0xbd34fc6AAa1d3F52B314CB9D78023dd23eAc3B0E
            vault:  ALLOCATOR_PATTERN_A_VAULT,
            // ilkInstance.buffer: 0x823459b55D79F0421f24a4828237F7ecb8D7F1ef
            buffer: ALLOCATOR_PATTERN_A_BUFFER
        });

        // Note: Set cfg with the following parameters:
        AllocatorIlkConfig memory allocatorIlkCfg = AllocatorIlkConfig({
            // cfg.ilk: ALLOCATOR-PATTERN-A
            ilk:            "ALLOCATOR-PATTERN-A",
            // cfg.duty: 0
            duty:           ZERO_PCT_RATE,
            // cfg.gap: 10 million USDS
            gap:            10_000_000 * RAD,
            // cfg.maxLine: 10 million USDS
            maxLine:        10_000_000 * RAD,
            // cfg.ttl: 86,400 seconds
            ttl:            86_400,
            // cfg.AllocatorProxy: 0xbC8959Ae2d4E9B385Fe620BEF48C2FD7f4A84736
            allocatorProxy: ALLOCATOR_PATTERN_A_SUBPROXY,
            // cfg.ilkRegistry: ILK_REGISTRY from chainlog
            ilkRegistry:    ILK_REGISTRY
        });

        // Note: We also need dss as an input parameter for initIlk
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Note: Now we can execute the initial instruction with all the relevant parameters by calling AllocatorInit.initIlk
        AllocatorInit.initIlk(dss, allocatorSharedInstance, allocatorIlkInstance, allocatorIlkCfg);

        // Remove newly created PIP_ALLOCATOR_PATTERN_A from chainlog
        // Note: PIP_ALLOCATOR_PATTERN_A was added to the chainlog when calling AllocatorInit.initIlk above
        ChainlogAbstract(DssExecLib.LOG).removeAddress("PIP_ALLOCATOR_PATTERN_A");

        // Add ALLOCATOR-PATTERN-A ilk to the LINE_MOM
        LineMomLike(LINE_MOM).addIlk("ALLOCATOR-PATTERN-A");

        // Add ALLOCATOR-PATTERN-A ilk to the SP-BEAM with the following parameters:
        // max: 3,000 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-PATTERN-A", "max", 3_000);

        // min: 0 bps
        // Note: min is not set as it is set to 0 bps by default

        // step: 400 bps
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-PATTERN-A", "step", 400);

        // Init new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0xbC8959Ae2d4E9B385Fe620BEF48C2FD7f4A84736
                subProxy: ALLOCATOR_PATTERN_A_SUBPROXY,
                // cfg.subProxyKey: PATTERN_SUBPROXY
                subProxyKey: "PATTERN_SUBPROXY",
                // cfg.starGuard: 0x2fb18b28fB39Ec3b26C3B5AF5222e2ca3B8B2269
                starGuard: PATTERN_STARGUARD,
                // cfg.starGuardKey: PATTERN_STARGUARD
                starGuardKey: "PATTERN_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add PATTERN_STARGUARD module to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(PATTERN_STARGUARD);

        // ---------- Skybase Onboarding and Genesis Capital Funding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-new-skybase-agent/27642
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-19/27627
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-01-19/27627/3
        // Atlas: https://sky-atlas.io/#A.2.8.2.7.2.2

        // Initialize new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x08978E3700859E476201c1D7438B3427e3C81140
                subProxy: SKYBASE_SUBPROXY,
                // cfg.subProxyKey: SKYBASE_SUBPROXY
                subProxyKey: "SKYBASE_SUBPROXY",
                // cfg.StarGuard: 0xA170086AeF9b3b81dD73897A0dF56B55e4C2a1F7
                starGuard: SKYBASE_STARGUARD,
                // cfg.starGuardKey: SKYBASE_STARGUARD
                starGuardKey: "SKYBASE_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add SKYBASE_STARGUARD to the StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(SKYBASE_STARGUARD);

        // Note: Bump chainlog patch version as new keys are being added
        DssExecLib.setChangelogVersion("1.20.11");

        // Transfer 10 million USDS to SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 10 * MILLION * WAD);

        // Transfer 5 million USDS to the USDS Demand Subsidies Multisig at 0x3F32bC09d41eE699844F8296e806417D6bf61Bba
        _transferUsds(USDS_DEMAND_SUBSIDIES_MULTISIG, 5 * MILLION * WAD);

        // ---------- DAO Resolution for RWA001-A ----------
        // Forum: https://forum.sky.money/t/rwa-001-6s-capital-update-and-stability-fee-proposal/24624/4
        // Forum: https://forum.sky.money/t/rwa-001-6s-capital-update-and-stability-fee-proposal/24624/5

        // Approve DAO Resolution with hash bafkreiczdjq55zsxvxcf4le3oaqvhp4jgvls4n4b7xbnzvkwilzen3a2te
        // Note: see `dao_resolutions` public variable declared above

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/january-29-2026-proposed-changes/27620
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.3.2.1.2.1
        // Atlas: https://sky-atlas.io/#A.2.8.2.2.2.5.5.2
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x7888032804772315db4be8e2d0c59ec50c70fbc0d4e7c5bab0af0a4b7391070e
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x64bd800579115f0a11a1290af898bdbe587947cd483afab3998b8454e3a4fb2d
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xa1b2e3a136cca3a6df5498a074aeecad8bee871866726b7568b19c087ff33178

        // Whitelist Spark spell with address 0xa091BeD493C27efaa4D6e06e32684eCa0325adcA and codehash 0x6ef4bf2258afab1e1c857892e5253e95880230a86ee9adc773fab559d7a594ec in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.1.4.2.1.2.4

        // Whitelist Grove spell with address 0x67aB5b15E3907E3631a303c50060c2207465a9AD and codehash 0x7e4eb1e46f50b347fc7c8d20face6070c8fda4876049e32f3877a89cede1d533 in GROVE_STARGUARD, direct execution: No
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
