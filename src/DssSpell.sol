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
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
// Note: code matches https://github.com/sky-ecosystem/star-guard/blob/52239d716a89188b303f137fc43fb9288735ba2e/deploy/StarGuardInit.sol
import { StarGuardInit, StarGuardConfig } from "src/dependencies/star-guard/StarGuardInit.sol";

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface GovernanceOAppSenderLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

interface SubProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-11-27 MakerDAO Executive Spell | Hash: TODO";

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
    address internal immutable CHAINLOG                 = DssExecLib.LOG;
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable MCD_SPBEAM               = DssExecLib.getChangelogAddress("MCD_SPBEAM");
    address internal immutable ALLOCATOR_SPARK_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable LZ_GOV_SENDER            = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable CRON_STARGUARD_JOB       = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");

    address internal constant GROVE_STARGUARD       = 0xfc51CAa049E8894bEcFfB68c61095C3F3Ec8a880;
    address internal constant KEEL_STARGUARD        = 0xe8fF70481d653Ec31AB9E0cB2A8B316afF8D84ee;
    address internal constant OBEX_STARGUARD        = 0x987f1C31f9935e9926555BcFB76516bb2EcEccaD;

    // ---------- Spark Spell ----------
    address internal immutable SPARK_STARGUARD  = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal constant  SPARK_SPELL      = 0x2C9E477313EC440fe4Ab6C98529da2793e6890F2;
    bytes32 internal constant  SPARK_SPELL_HASH = 0xfad4d50e95e43a5d172619770dac42160a77258693d15be09343c5b29f88c521;

    // ---------- Keel Spell ----------
    address internal constant KEEL_SPELL = 0x2395AF361CdF86d348B07E109E710943AFDb23aa;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG      = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG    = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;

    address internal constant AEGIS_D       = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
    address internal constant BLUE          = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA   = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2      = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant SKY_STAKING   = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;
    address internal constant TANGO         = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant GNOSIS        = 0x849D52316331967b6fF1198e5E32A0eB168D039d;

    // ---------- LayerZero ----------
    uint32 internal constant SOL_EID = 30168;
    // Note: base58 ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd&output_type=hex
    bytes32 internal constant SVM_CONTROLLER = 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;
    // Note: base58 BPFLoaderUpgradeab1e11111111111111111111111 to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=BPFLoaderUpgradeab1e11111111111111111111111&output_type=hex
    bytes32 internal constant BPF_LOADER = 0x02a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a1004800000;

    // ---------- Spark Proxy ----------
    address internal immutable SPARK_SUBPROXY = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");

    // ---------- Grove Proxy ----------
    // Note: The deployment address for the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant GROVE_SUBPROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;

    // ---------- Keel Proxy ----------
    // Note: The deployment address of the Keel Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-nova-allocator-adjustment/27175
    address internal constant KEEL_SUBPROXY = 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310;

    // ---------- Obex Proxy ----------
    // Note: The deployment address of the Obex Proxy can be found at https://forum.sky.money/t/technical-scope-launch-of-the-agent-4-allocation-system/27314
    address internal constant OBEX_SUBPROXY = 0x8be042581f581E3620e29F213EA8b94afA1C8071;

    function actions() public override {
        // ---------- Launch Grove StarGuard ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-starguard-launches-for-grove-keel-and-obex/27441
        // Poll: https://vote.sky.money/polling/QmSKnB98

        // Call StarGuardInit.init with the following parameters:
        StarGuardInit.init(
            // address chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba
                subProxy: GROVE_SUBPROXY,
                // cfg.subProxyKey: GROVE_SUBPROXY
                subProxyKey: "GROVE_SUBPROXY",
                // cfg.starGuard: 0xfc51CAa049E8894bEcFfB68c61095C3F3Ec8a880
                starGuard: GROVE_STARGUARD,
                // cfg.starGuardKey: GROVE_STARGUARD
                starGuardKey: "GROVE_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add Grove StarGuard to StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(GROVE_STARGUARD);

        // ---------- Launch Keel StarGuard ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-starguard-launches-for-grove-keel-and-obex/27441
        // Poll: https://vote.sky.money/polling/QmSKnB98

        // Call StarGuardInit.init with the following parameters:
        StarGuardInit.init(
            // address chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310
                subProxy: KEEL_SUBPROXY,
                // cfg.subProxyKey: KEEL_SUBPROXY
                subProxyKey: "KEEL_SUBPROXY",
                // cfg.starGuard: 0xe8fF70481d653Ec31AB9E0cB2A8B316afF8D84ee
                starGuard: KEEL_STARGUARD,
                // cfg.starGuardKey: KEEL_STARGUARD
                starGuardKey: "KEEL_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add Keel StarGuard to StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(KEEL_STARGUARD);

        // ---------- Launch Obex StarGuard ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-starguard-launches-for-grove-keel-and-obex/27441
        // Poll: https://vote.sky.money/polling/QmSKnB98

        // Call StarGuardInit.init with the following parameters:
        StarGuardInit.init(
            // address chainlog: DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy: 0x8be042581f581E3620e29F213EA8b94afA1C8071
                subProxy: OBEX_SUBPROXY,
                // cfg.subProxyKey: OBEX_SUBPROXY
                subProxyKey: "OBEX_SUBPROXY",
                // cfg.starGuard: 0x987f1C31f9935e9926555BcFB76516bb2EcEccaD
                starGuard: OBEX_STARGUARD,
                // cfg.starGuardKey: OBEX_STARGUARD
                starGuardKey: "OBEX_STARGUARD",
                // cfg.maxDelay: 7 days
                maxDelay: 7 days
            })
        );

        // Add Obex StarGuard to StarGuardJob
        StarGuardJobLike(CRON_STARGUARD_JOB).add(OBEX_STARGUARD);

        // Note: Bump chainlog patch version as new keys are being added
        DssExecLib.setChangelogVersion("1.20.9");

        // ---------- Monthly Settlement Cycle and Treasury Management Function for October ----------
        // Forum: https://forum.sky.money/t/msc-3-settlemnt-summary-october-2025-initial-calculation/27397/3
        // Atlas: https://sky-atlas.io/#A.2.5
        // Atlas: https://sky-atlas.io/#A.2.4.1.4.1.1
        // Atlas: https://sky-atlas.io/#A.2.4.1.4.1.2

        // Mint 16,332,535 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_332_535 * WAD);

        // Transfer 4,642,240 USDS from the Surplus Buffer to the Spark SubProxy at 0x3300f198988e4C9C63F75dF86De36421f06af8c4
        _transferUsds(SPARK_SUBPROXY, 4_642_240 * WAD);

        // Mint 4,196,768 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 4_196_768 * WAD);

        // Transfer 3,177,413 USDS to the Core Council Buffer Multisig at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_177_413 * WAD);

        // Transfer 158,871 USDS to the Aligned Delegates Buffer Multisig at 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 158_871 * WAD);

        // ---------- Whitelist the Keel SubProxy to Send Cross-Chain Messages to Solana ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-17/27421
        // Forum: https://forum.sky.money/t/executive-inclusion-whitelisting-the-keel-subproxy-to-send-cross-chain-messages-to-solana/27447
        // Poll: https://vote.sky.money/polling/QmdomJ7o

        // Call setCanCallTarget on LZ_GOV_SENDER with the following parameters:
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            // _srcSender: KEEL_SUBPROXY
            KEEL_SUBPROXY,
            // _dstEID: SOL_EID defined by LayerZero
            SOL_EID,
            // _dstTarget: ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
            SVM_CONTROLLER,
            // _canCall: true
            true
        );

        // Call setCanCallTarget on LZ_GOV_SENDER with the following parameters:
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            // _srcSender: KEEL_SUBPROXY
            KEEL_SUBPROXY,
            // _dstEID: SOL_EID defined by LayerZero
            SOL_EID,
            // _dstTarget: BPFLoaderUpgradeab1e11111111111111111111111
            BPF_LOADER,
            // _canCall: true
            true
        );

        // ---------- Delegate Compensation for October ----------
        // Forum: https://forum.sky.money/t/october-2025-ranked-delegate-compensation/27412
        // Atlas: https://sky-atlas.io/#A.1.5

        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        _transferUsds(AEGIS_D, 4_000 * WAD);

        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // Transfer 3,783 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        _transferUsds(SKY_STAKING, 3_783 * WAD);

        // Transfer 3,696 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 3_696 * WAD);

        // ---------- Atlas Core Development USDS Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-november-2025/27402
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 50,167 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // Transfer 16,417 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // ---------- Atlas Core Development SKY Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-november-2025/27402
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 330,000 SKY to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

        // Transfer 288,000 SKY to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // ---------- Payment to Gnosis ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-10/27400
        // Atlas: https://sky-atlas.io/#A.4.1.1.1.1

        // Transfer 1,806,670 USDS to Gnosis at 0x849D52316331967b6fF1198e5E32A0eB168D039d
        _transferUsds(GNOSIS, 1_806_670 * WAD);

        // ---------- Add ALLOCATOR-OBEX-A to SP-BEAM ----------
        // Forum: https://forum.sky.money/t/executive-inclusion-add-allocator-obex-a-to-the-sp-beam/27442
        // Atlas: https://sky-atlas.io/#A.3.7.1.2.3

        // Add ALLOCATOR-OBEX-A to SP-BEAM with the following parameters:
        // max: 3,000 basis points
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-OBEX-A", "max", 3_000);
        
        // min: 0 basis points
        // Note: min is not set as it is set to 0 basis points by default
        
        // step: 400 basis points
        DssExecLib.setValue(MCD_SPBEAM, "ALLOCATOR-OBEX-A", "step", 400);

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27418
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27419
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27420
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27421
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27422
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27423
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27424
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27425
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27426
        // Forum: https://forum.sky.money/t/november-27-2025-proposed-changes-to-spark-for-upcoming-spell/27427
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x9dd06e68b3b109b616cc7cf7af7f1cf78ed9408312bfb9fe43764a3b3dba563a
        // Poll: https://vote.sky.money/polling/QmTNrfXk
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xcaafeb100a8ec75ae1e1e9d4059f7d2ec2db31aa55a09be2ec2c7467e0f10799
        // Atlas: https://sky-atlas.io/#A.2.9.2.2.2.5.5.1
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3

        // Whitelist the Spark Proxy Spell deployed to 0x2C9E477313EC440fe4Ab6C98529da2793e6890F2 with codehash 0xfad4d50e95e43a5d172619770dac42160a77258693d15be09343c5b29f88c521; direct execution: no in Spark Starguard
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Execute Keel Proxy Spell ----------
        // Forum: https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406
        // Forum: https://forum.sky.money/t/november-27-2025-prime-technical-scope-solana-pre-configuration-for-upcoming-spell/27404
        // Poll: https://vote.sky.money/polling/QmdomJ7o

        // Execute Keel Proxy Spell at 0x2395AF361CdF86d348B07E109E710943AFDb23aa
        SubProxyLike(KEEL_SUBPROXY).exec(KEEL_SPELL, abi.encodeWithSignature("execute()"));
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
