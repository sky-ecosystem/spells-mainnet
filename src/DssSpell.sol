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

    function actions() public override {
        // ---------- Launch Grove StarGuard ----------
        // Call StarGuardInit.init with the following parameters:
        // address chainlog: DssExecLib.LOG
        // cfg.subProxy: 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba
        // cfg.subProxyKey: GROVE_SUBPROXY
        // cfg.starGuard: 0xfc51CAa049E8894bEcFfB68c61095C3F3Ec8a880
        // cfg.starGuardKey: GROVE_STARGUARD
        // cfg.maxDelay: 7 days
        // Add Grove StarGuard to StarGuardJob

        // ---------- Launch Keel StarGuard ----------
        // Call StarGuardInit.init with the following parameters:
        // address chainlog: DssExecLib.LOG
        // cfg.subProxy: 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310
        // cfg.subProxyKey: KEEL_SUBPROXY
        // cfg.starGuard: 0xe8fF70481d653Ec31AB9E0cB2A8B316afF8D84ee
        // cfg.starGuardKey: KEEL_STARGUARD
        // cfg.maxDelay: 7 days
        // Add Keel StarGuard to StarGuardJob

        // ---------- Launch Obex StarGuard ----------
        // Call StarGuardInit.init with the following parameters:
        // address chainlog: DssExecLib.LOG
        // cfg.subProxy: 0x8be042581f581E3620e29F213EA8b94afA1C8071
        // cfg.subProxyKey: OBEX_SUBPROXY
        // cfg.starGuard: 0x987f1C31f9935e9926555BcFB76516bb2EcEccaD
        // cfg.starGuardKey: OBEX_STARGUARD
        // cfg.maxDelay: 7 days
        // Add Obex StarGuard to StarGuardJob

        // ---------- Monthly Settlement Cycle and Treasury Management Function for October ----------

        // Spark
        // Note: This is only a subheading, actual instructions follow below.
        // Mint 16,332,535 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the Surplus Buffer
        // Transfer 4,642,240 USDS from the Surplus Buffer to the Spark SubProxy at 0x3300f198988e4C9C63F75dF86De36421f06af8c4

        // Bloom/Grove
        // Note: This is only a subheading, actual instructions follow below.
        // Mint 4,196,768 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the Surplus Buffer
        // Transfer 3,177,413 USDS to the Core Council Buffer Multisig at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364
        // Transfer 158,871 USDS to the Aligned Delegates Buffer Multisig at 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3

        // ---------- Whitelist the Keel SubProxy to Send Cross-Chain Messages to Solana ----------
        // Call setCanCallTarget on LZ_GOV_SENDER with the following parameters:
        // _srcSender: KEEL_SUBPROXY
        // _dstEID: SOL_EID defined by LayerZero
        // _dstTarget: ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
        // _canCall: true

        // Call setCanCallTarget on LZ_GOV_SENDER with the following parameters:
        // _srcSender: KEEL_SUBPROXY
        // _dstEID: SOL_EID defined by LayerZero
        // _dstTarget: BPFLoaderUpgradeab1e11111111111111111111111
        // _canCall: true

        // ---------- Delegate Compensation for October ----------
        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        // Transfer 3,783 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        // Transfer 3,696 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307

        // ---------- Atlas Core Development USDS Payments ----------
        // Transfer 50,167 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        // Transfer 16,417 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // ---------- Atlas Core Development SKY Payments ----------
        // Transfer 330,000 SKY to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        // Transfer 288,000 SKY to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5

        // ---------- Payment to Gnosis ----------
        // Transfer 1,806,670 USDS to Gnosis at 0x849D52316331967b6fF1198e5E32A0eB168D039d

        // ---------- Add ALLOCATOR-OBEX-A to SP-BEAM ----------
        // Add ALLOCATOR-OBEX-A to SP-BEAM with the following parameters:
        // max: 3,000 basis points
        // min: 0 basis points
        // step: 400 basis points

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Whitelist the Spark Proxy Spell deployed to 0x2C9E477313EC440fe4Ab6C98529da2793e6890F2 with codehash 0xfad4d50e95e43a5d172619770dac42160a77258693d15be09343c5b29f88c521; direct execution: no in Spark Starguard

        // ----------Execute Keel Proxy Spell ----------
        // Execute Keel Proxy Spell at TODO
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
