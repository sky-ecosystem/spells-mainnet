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
import { ChainlogAbstract } from "dss-interfaces/dss/ChainlogAbstract.sol";
import { GemJoinAbstract } from "dss-interfaces/dss/GemJoinAbstract.sol";
import { IlkRegistryAbstract } from "dss-interfaces/dss/IlkRegistryAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
// Copied from https://github.com/sky-ecosystem/endgame-toolkit/blob/4f238f9b23298190150d49482bad56c00f0af825/script/dependencies/treasury-funded-farms/TreasuryFundedFarmingInit.sol
import { TreasuryFundedFarmingInit, FarmingUpdateVestParams } from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";
// Copied from https://github.com/sky-ecosystem/star-guard/blob/52239d716a89188b303f137fc43fb9288735ba2e/deploy/StarGuardInit.sol
import { StarGuardInit, StarGuardConfig } from "./dependencies/star-guard/StarGuardInit.sol";

interface SkyLike {
    function burn(address from, uint256 value) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface LineMomLike {
    function delIlk(bytes32 ilk) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface IEnumerableIntegrations {
    struct Config {
        address facet;
        Wire[] wires;
    }

    struct Wire {
        bytes4 callSelector;
        bytes4 delegateSelector;
    }
}

interface BeaconLike {
    function getConfig(bytes32 integrationId) external view returns (IEnumerableIntegrations.Config memory);
    function setIntegration(bytes32 id, IEnumerableIntegrations.Config calldata config) external;
}

interface BeamStateLike {
    function addCBeam(address cBeam) external;
    function addRateLimits(address rateLimits_) external;
    function setCBeamForRateLimits(address rateLimits_, address cBeam) external;
    function addController(address controller) external;
    function setCBeamForController(address controller, address cBeam) external;
}

interface OpL1GovernanceRelayLike {
    function relay(address target, bytes calldata targetData, uint32 minGasLimit) external;
}

interface L2MulticallSpellLike {
    struct Call {
        address target;
        bytes data;
    }

    function execute(Call[] calldata calls, uint256 deadline) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/ee8e579bdccdcffdd88c7c12d75b0f498091ec50/2026/executive-vote-2026-11-19-msc-psm-offboard-launch-test-halo-launch-osero-base-dpau.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-11-19 MakerDAO Executive Spell | Hash: 0x243d9365fb931a4d88928e5ba11f8fc5a66af973401097d7a65e01ed0d618fe1";

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
    uint256 internal constant WAD         = 10 ** 18;
    uint256 internal constant RAY         = 10 ** 27;
    uint256 internal constant USDC_TO_WAD = 10 ** 12;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable MCD_DOG                  = DssExecLib.dog();
    address internal immutable ILK_REGISTRY             = DssExecLib.reg();
    address internal immutable LINE_MOM                 = DssExecLib.getChangelogAddress("LINE_MOM");
    address internal immutable CHANGELOG                = DssExecLib.LOG;
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
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable REWARDS_DIST_LSSKY_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable MCD_JOIN_PSM_USDC_A      = DssExecLib.getChangelogAddress("MCD_JOIN_PSM_USDC_A");
    address internal immutable MCD_CLIP_PSM_USDC_A      = DssExecLib.getChangelogAddress("MCD_CLIP_PSM_USDC_A");
    address internal immutable CRON_STARGUARD_JOB       = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");
    address internal immutable PAU_BEACON               = DssExecLib.getChangelogAddress("PAU_BEACON");
    address internal immutable BASE_GOV_RELAY           = DssExecLib.getChangelogAddress("BASE_GOV_RELAY");
    address internal immutable SAFE_HARBOR_AGREEMENT    = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable OSERO_STARGUARD          = DssExecLib.getChangelogAddress("OSERO_STARGUARD");
    address internal constant  TEST_HALO_SUBPROXY       = 0xF12Be1673758f8fBC275755401774Ec45C80c0F0;
    address internal constant  TEST_HALO_STARGUARD      = 0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056;

    // ---------- Base Contracts ----------
    address internal constant L2_PAU_BEACON          = 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41;
    address internal constant L2_PAS_STATE           = 0x29840a8519013F483d94781b5C1671b552A109e1;
    address internal constant L2_ERC4626_FACET       = 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D;
    address internal constant L2_MULTICALL_SPELL     = 0x682048513247076Fb5dB4762121BdB136182e4A9;
    address internal constant OSERO_PAS_CBEAM        = 0x42D1038017E466b413aa44Ae798E30FB80b2E180;
    address internal constant BASE_OSERO_RATE_LIMITS = 0xd9E629588c48722E4c1bfcfb17829FecAf73839f;
    address internal constant BASE_OSERO_CONTROLLER  = 0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant DEMAND_SIDE_BUFFER_MULTISIG  = 0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0x0703EBA65Ff30c245f739087B4c5280e9e4dBD50;
    bytes32 internal constant SPARK_SPELL_HASH = 0x0a88e3ab7468f13e69d3e49699ccd8463dedc9609ea097e23c19e6106810e6c8;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0x1a74cC68A37f24367914fAc1915cC604CB3D72AF;
    bytes32 internal constant GROVE_SPELL_HASH = 0x45f2833db32128803bd3ce7dc8fa9837a38db7791cacd99ac1c90598d0a70bc9;

    // ---------- Osero Spell ----------
    address internal constant OSERO_SPELL      = 0xC1989b5c81eA2bC4A6Abda0e73e3E3C48D500d05;
    bytes32 internal constant OSERO_SPELL_HASH = 0xd99ef190c8ebdfbe3ddd67e84a2d63243b0f354e4841928a8bc6869a4055d77b;

    function actions() public override {
        // ---------- Monthly Settlement Cycle for October 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-14-settlement-summary-october-2026/28406
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 14,048,690 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 14_048_690 * WAD);

        // Send 4,188,099 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 4_188_099 * WAD);

        // Mint 8,866,792 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 8_866_792 * WAD);

        // Send 2,170,826 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 2_170_826 * WAD);

        // Send 34,034 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 34_034 * WAD);

        // Mint 1,463,217 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_463_217 * WAD);

        // Send 205,907 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 205_907 * WAD);

        // Send 145,439 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 145_439 * WAD);

        // Mint 15,812 USDS debt in ALLOCATOR-PRYSM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_PRYSM_A_VAULT, 15_812 * WAD);

        // Send 42,396 USDS from the surplus buffer to the OSERO_SUBPROXY
        _transferUsds(OSERO_SUBPROXY, 42_396 * WAD);

        // Send 1,000,000 USDS from the surplus buffer to the Demand Side Buffer at 0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B
        _transferUsds(DEMAND_SIDE_BUFFER_MULTISIG, 1_000_000 * WAD);

        // ---------- Treasury Management Function ----------
        // Forum: https://forum.skyeco.com/t/treasury-management-function-tmf-configurations/28153/10
        // Atlas: https://sky-atlas.io/#f67a5780-11d5-4014-8254-795080c77133

        // Send 3,720,082 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_720_082 * WAD);

        // Burn 7,770,211 SKY tokens from the PauseProxy Balance
        SkyLike(SKY).burn(address(this), 7_770_211 * WAD);

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist:    REWARDS_DIST_LSSKY_SKY,
            // vestTot: 104,897,852 SKY
            vestTot: 104_897_852 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- Adjust Core Vault DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/core-vaults-parameter-changes-set-dc-iam-line-to-0-on-eth-a-eth-b-eth-c-wsteth-a-and-wsteth-b/28399
        // Atlas: https://sky-atlas.io/#2107f160-751d-4fea-abc0-f0bef76a30d5

        // Note: Accumulate the unused capacity removed from the five ilks, in RAD.
        uint256 globalLineReduction = 0;

        // Remove ETH-A from autoline
        DssExecLib.removeIlkFromAutoLine("ETH-A");

        // Set ETH-A Debt Ceiling to 0
        globalLineReduction += _zeroIlkDebtCeiling("ETH-A");

        // Remove ETH-B from autoline
        DssExecLib.removeIlkFromAutoLine("ETH-B");

        // Set ETH-B Debt Ceiling to 0
        globalLineReduction += _zeroIlkDebtCeiling("ETH-B");

        // Remove ETH-C from autoline
        DssExecLib.removeIlkFromAutoLine("ETH-C");

        // Set ETH-C Debt Ceiling to 0
        globalLineReduction += _zeroIlkDebtCeiling("ETH-C");

        // Remove WSTETH-A from autoline
        DssExecLib.removeIlkFromAutoLine("WSTETH-A");

        // Set WSTETH-A Debt Ceiling to 0
        globalLineReduction += _zeroIlkDebtCeiling("WSTETH-A");

        // Remove WSTETH-B from autoline
        DssExecLib.removeIlkFromAutoLine("WSTETH-B");

        // Set WSTETH-B Debt Ceiling to 0
        globalLineReduction += _zeroIlkDebtCeiling("WSTETH-B");

        // Note: Reduce only unused capacity, retaining room for the five ilks' existing debt as recorded in the Vat.
        DssExecLib.setValue(MCD_VAT, "Line", VatAbstract(MCD_VAT).Line() - globalLineReduction);

        // ---------- Finalize Legacy USDC PSM Offboarding ----------
        // Forum: https://forum.skyeco.com/t/psm-usdc-a-housekeeping/28417
        // Atlas: https://sky-atlas.io/#0d0e2e1a-0502-4ee3-bc9d-8bd8ddde19ec

        // Send rescued USDC to the CC Buffer at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364
        // Note: Attempt recovery before revoking the Join's authorization on the Vat.
        _tryRecoverUsdc({
            ilk:       "PSM-USDC-A",
            join:      MCD_JOIN_PSM_USDC_A,
            recipient: CORE_COUNCIL_BUDGET_MULTISIG,
            amount:    99_328_577
        });

        // Finalize Offboarding of the Legacy USDC PSM
        _offboardPsm({
            ilk:  "PSM-USDC-A",
            join: MCD_JOIN_PSM_USDC_A,
            clip: MCD_CLIP_PSM_USDC_A
        });

        // Note: Remove the offboarded PSM's related addresses from the Chainlog.
        ChainlogAbstract(CHANGELOG).removeAddress("MCD_PSM_USDC_A");
        ChainlogAbstract(CHANGELOG).removeAddress("MCD_JOIN_PSM_USDC_A");
        ChainlogAbstract(CHANGELOG).removeAddress("MCD_CLIP_PSM_USDC_A");
        ChainlogAbstract(CHANGELOG).removeAddress("MCD_CLIP_CALC_PSM_USDC_A");

        // ---------- Initialize Test Halo SubProxy and StarGuard ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-for-the-new-test-halo-agent-setup/28418
        // Poll: https://vote.sky.money/polling/QmPNbnSS

        // Call StarGuardInit.init with chainlog = DssExecLib.LOG, cfg.subProxy = 0xF12Be1673758f8fBC275755401774Ec45C80c0F0, cfg.subProxyKey = TEST_HALO_SUBPROXY, cfg.starGuard = 0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056, cfg.starGuardKey = TEST_HALO_STARGUARD, and cfg.maxDelay = 7 days.
        StarGuardInit.init(DssExecLib.LOG, StarGuardConfig({
            subProxy:     TEST_HALO_SUBPROXY,
            subProxyKey:  "TEST_HALO_SUBPROXY",
            starGuard:    TEST_HALO_STARGUARD,
            starGuardKey: "TEST_HALO_STARGUARD",
            maxDelay:     7 days
        }));

        // Call CRON_STARGUARD_JOB.add(0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056).
        StarGuardJobLike(CRON_STARGUARD_JOB).add(TEST_HALO_STARGUARD);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.23");

        // ---------- [Base] Configure the Beacon and PAS for Osero’s DPAU Launch ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-core-l2-spell-on-base-assisting-osero-s-dpau-launch/28413
        // Atlas: https://sky-atlas.io/#24c2fc14-448d-48be-a416-86bfad6f33fe

        L2MulticallSpellLike.Call[] memory calls = new L2MulticallSpellLike.Call[](6);

        // Call L2_PAU_BEACON.setIntegration for bytes32("ERC4626_FACET") with facet = 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D and wires copied from Ethereum mainnet PAU_BEACON.getConfig(bytes32("ERC4626_FACET")).wires.
        // Note: Read the current Ethereum configuration during the Core cast.
        IEnumerableIntegrations.Config memory config = BeaconLike(PAU_BEACON).getConfig("ERC4626_FACET");
        // Note: Keep its wires and substitute only the Base facet address.
        config.facet = L2_ERC4626_FACET;
        calls[0] = L2MulticallSpellLike.Call(
            L2_PAU_BEACON,
            abi.encodeCall(BeaconLike.setIntegration, ("ERC4626_FACET", config))
        );

        // Call L2_PAS_STATE.addCBeam(0x42D1038017E466b413aa44Ae798E30FB80b2E180).
        calls[1] = L2MulticallSpellLike.Call(
            L2_PAS_STATE,
            abi.encodeCall(BeamStateLike.addCBeam, (OSERO_PAS_CBEAM))
        );

        // Call L2_PAS_STATE.addRateLimits(0xd9E629588c48722E4c1bfcfb17829FecAf73839f).
        calls[2] = L2MulticallSpellLike.Call(
            L2_PAS_STATE,
            abi.encodeCall(BeamStateLike.addRateLimits, (BASE_OSERO_RATE_LIMITS))
        );

        // Call L2_PAS_STATE.setCBeamForRateLimits(0xd9E629588c48722E4c1bfcfb17829FecAf73839f, 0x42D1038017E466b413aa44Ae798E30FB80b2E180).
        calls[3] = L2MulticallSpellLike.Call(
            L2_PAS_STATE,
            abi.encodeCall(BeamStateLike.setCBeamForRateLimits, (BASE_OSERO_RATE_LIMITS, OSERO_PAS_CBEAM))
        );

        // Call L2_PAS_STATE.addController(0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9).
        calls[4] = L2MulticallSpellLike.Call(
            L2_PAS_STATE,
            abi.encodeCall(BeamStateLike.addController, (BASE_OSERO_CONTROLLER))
        );

        // Call L2_PAS_STATE.setCBeamForController(0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9, 0x42D1038017E466b413aa44Ae798E30FB80b2E180).
        calls[5] = L2MulticallSpellLike.Call(
            L2_PAS_STATE,
            abi.encodeCall(BeamStateLike.setCBeamForController, (BASE_OSERO_CONTROLLER, OSERO_PAS_CBEAM))
        );

        // From the Ethereum Core spell, call BASE_GOV_RELAY.relay targeting 0x682048513247076Fb5dB4762121BdB136182e4A9. Encode L2MulticallSpell.execute with the six Base calls above in order and deadline = block.timestamp + 7 days at the Ethereum cast. Set minGasLimit = 1_000_000.
        OpL1GovernanceRelayLike(BASE_GOV_RELAY).relay(
            L2_MULTICALL_SPELL,
            abi.encodeCall(L2MulticallSpellLike.execute, (calls, block.timestamp + 7 days)),
            1_000_000
        );

        // ---------- Update Safe Harbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](2);

        // Add accounts to eip155:1 chain: 0xF12Be1673758f8fBC275755401774Ec45C80c0F0 (scope=0), 0x5dc7A3700Dc0508f5E127FA23acd83cc2E1D6056 (scope=0)
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078463132426531363733373538663866424332373537353534303137373445633435433830633046300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783564633741333730304463303530386635453132374641323361636438336363324531443630353600000000000000000000000000000000000000000000';

        // Add accounts to eip155:8453 chain: 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D (scope=0), 0x682048513247076Fb5dB4762121BdB136182e4A9 (scope=0)
        calldatas[1] = hex'46c2b73400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b6569703135353a383435330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078433646623534333438666543646232373930466139313330443166633335643645313031433937440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783638323034383531333234373037364662356442343736323132314264423133363138326534413900000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-spark-for-upcoming-spell/28390
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x5547b7f06c852c98c517e53fb8f2516062d7d890c9abd1bd7b2c9a5db67f9289
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Poll: https://vote.sky.money/polling/QmYWJPcE
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf1426e0ea2fcab571a5d59e650b24a88f56c041efe8ddc31d22a9d354dd57f97
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x38093a3ead044a60511d1451ae04d0768e65b4ac32e19069c4d78335b64df61d
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x61efe7dcaadc2baf6b0dde519ceb3e360f7ac864c888004108d97012843246ed
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x4ca8fbf47c4679aa74d3cd6681c89ced9383e9f923b7dc6f33c94f7f8f0cee5b
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x807d260ba5b828e4e886727c66b4bb5666a76a8dcf78cff89bb2584f7580ea17

        // Whitelist Spark spell with address 0x0703EBA65Ff30c245f739087B4c5280e9e4dBD50 and codehash 0x0a88e3ab7468f13e69d3e49699ccd8463dedc9609ea097e23c19e6106810e6c8 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-grove-for-upcoming-spell/28387
        // Poll: https://vote.sky.money/polling/QmYWJPcE
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x6a024ffdd779c80702e6c11dd8343a64627e7bfe5cfe4f33b1a4fa6cd3f3a5cf
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x6b470d2a31a6e1723376a35691a551c521739d85f9f55672793857405cab88a5
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x319e9c02e0cbd1a4c9e1647fdb5b2c7ad99bc7076b3a7cd5f49c58d8a1d7cdef

        // Whitelist Grove spell with address 0x1a74cC68A37f24367914fAc1915cC604CB3D72AF and codehash 0x45f2833db32128803bd3ce7dc8fa9837a38db7791cacd99ac1c90598d0a70bc9  in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-osero-for-upcoming-spell/28388
        // Poll: https://vote.sky.money/polling/QmYWJPcE

        // Whitelist Osero spell with address 0xC1989b5c81eA2bC4A6Abda0e73e3E3C48D500d05 and codehash 0xd99ef190c8ebdfbe3ddd67e84a2d63243b0f354e4841928a8bc6869a4055d77b in OSERO_STARGUARD, direct execution: No
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

    // Note: This helper reduces runtime bytecode size to avoid enabling compiler optimization for the spell.
    /// @notice Sets an ilk's debt ceiling to zero.
    /// @param ilk The ilk to update.
    /// @return reduction The unused debt ceiling capacity in RAD.
    function _zeroIlkDebtCeiling(bytes32 ilk) internal returns (uint256 reduction) {
        // Note: Accrue stability fees before calculating the unused debt ceiling capacity.
        JugAbstract(MCD_JUG).drip(ilk);
        // Note: Read the current debt and ceiling before zeroing the ceiling.
        (uint256 Art, uint256 rate,, uint256 line,) = VatAbstract(MCD_VAT).ilks(ilk);
        // Note: Art (WAD) multiplied by rate (RAY) gives the recorded debt in RAD.
        uint256 debt = Art * rate;
        // Note: Retain capacity for existing debt, including when it meets or exceeds the ceiling.
        reduction = line > debt ? line - debt : 0;
        // Note: Zero the individual ceiling without changing the existing debt.
        DssExecLib.setIlkDebtCeiling(ilk, 0);
    }

    /// @notice Attempts to recover USDC before the Join is offboarded.
    /// @dev A failed exit is tolerated after reversing the temporary Vat gem credit.
    /// @param ilk The ilk whose Vat gem balance is credited
    /// @param join The address of the USDC join
    /// @param recipient The USDC recipient
    /// @param amount The USDC amount in six-decimal base units
    function _tryRecoverUsdc(bytes32 ilk, address join, address recipient, uint256 amount) internal {
        // Note: Convert the six-decimal USDC amount into the Vat's eighteen-decimal gem units.
        int256 gem = int256(amount * USDC_TO_WAD);
        // Note: Credit the executing proxy so the Join can debit this balance when exiting USDC.
        VatAbstract(MCD_VAT).slip(ilk, address(this), gem);
        // Note: Attempt to transfer the recovered USDC from the Join to the recipient.
        try GemJoinAbstract(join).exit(recipient, amount) {
        } catch {
            // Note: Undo only the temporary credit if exit fails, then continue offboarding.
            VatAbstract(MCD_VAT).slip(ilk, address(this), -gem);
        }
    }

    /// @notice Wraps the operations required to finish the offboarding of a PSM ilk.
    /// @param ilk The ilk to offboard
    /// @param join The address of the ilk join
    /// @param clip The address of the ilk clipper
    function _offboardPsm(bytes32 ilk, address join, address clip) internal {
        // Note: Remove ilk from ILK_REGISTRY
        IlkRegistryAbstract(ILK_REGISTRY).removeAuth(ilk);

        // Note: Remove ilk from LINE_MOM
        LineMomLike(LINE_MOM).delIlk(ilk);

        // Note: Cage the join
        GemJoinAbstract(join).cage();

        // Note: Revoke the join authorization on MCD_VAT
        DssExecLib.deauthorize(MCD_VAT, join);

        // Note: Revoke the Clipper authorization on MCD_VAT and MCD_DOG
        DssExecLib.deauthorize(MCD_VAT, clip);
        DssExecLib.deauthorize(MCD_DOG, clip);
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
