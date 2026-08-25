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
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";
// Copied from https://github.com/sky-ecosystem/pas/blob/947e71cd5dbaaf9c5b3840dd1b23e8e99d9a564d/deploy/PASInit.sol
import { InitCBeamConfig, PASInit } from "./dependencies/pas/PASInit.sol";
// Copied from https://github.com/sky-ecosystem/pas/blob/947e71cd5dbaaf9c5b3840dd1b23e8e99d9a564d/deploy/PASInstance.sol
import { PASInstance } from "./dependencies/pas/PASInstance.sol";

interface SubProxyMethodsLike {
    function transfer(address token, address to, uint256 amount) external;
}

interface SubProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-08-27 MakerDAO Executive Spell | Hash: TODO";

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

    // ---------- Contracts ----------
    address internal immutable USDS                       = DssExecLib.getChangelogAddress("USDS");
    address internal immutable MCD_PAUSE_PROXY            = DssExecLib.pauseProxy();
    address internal immutable MCD_IAM_AUTO_LINE          = DssExecLib.getChangelogAddress("MCD_IAM_AUTO_LINE");
    address internal immutable OWNER_REWARDS_LSSKY_USDS   = DssExecLib.getChangelogAddress("OWNER_REWARDS_LSSKY_USDS");
    address internal immutable SPARK_STARGUARD            = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD            = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable OZONE_SUBPROXY             = DssExecLib.getChangelogAddress("OZONE_SUBPROXY");
    address internal immutable SUBPROXY_METHODS           = DssExecLib.getChangelogAddress("SUBPROXY_METHODS");
    address internal immutable SAFE_HARBOR_AGREEMENT      = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");

    // ---------- PAS ----------
    address internal constant PAS_STATE          = 0x1A1879E66547F90bfF87D45A5b0335950E019E02;
    address internal constant PAS_CONFIGURATOR   = 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929;
    address internal constant PAS_TIMELOCK       = 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293;
    address internal constant PAS_MOM            = 0xD44B8d01D5207aA792C666d0A712A1A161CD6171;
    address internal constant PAS_CORE_COUNCIL   = 0x148eF923d764CBdc1597CcADBbbC66499C1A1432;
    address internal constant GROVE_RATE_LIMITS  = 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1;
    address internal constant GROVE_CONTROLLER   = 0xbf83F5974B932c7D842254042717D6A2706CE5eE;
    address internal constant GROVE_CBEAM        = 0x91dC2F6DbB8Adf76d373A54D408EDd7D736046C4;

    // ---------- Wallets ----------
    address internal constant SKY_FRONTIER_FOUNDATION = 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0xbE35b15Cda9002C1719A9D254B158613BDdE72af;
    bytes32 internal constant SPARK_SPELL_HASH = 0xd3d82d87849aa5a7df3105bac5e97518999288f8ce91ed80c83031a058a2fcf8;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0xF3d4F600640a87F4203DF0A554642228a119711e;
    bytes32 internal constant GROVE_SPELL_HASH = 0x89f28b693c551c87c8dbd632484c39e8e5e1ac040696ed7839776ba3beae23c5;

    function actions() public override {
        // ---------- PAS Initialization ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-parallelized-allocation-system-pas-module/28188
        // Poll: https://vote.sky.money/polling/Qmas6XKB

        // Note: We need a DssInstance as an input parameter for PASInit.addCoreToChainlog and PASInit.initMom
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Note: We need to declare a PASInstance for the PASInit calls below
        PASInstance memory pasInstance = PASInstance({
            // address pasInstance.beamState
            // Argument value: 0x1A1879E66547F90bfF87D45A5b0335950E019E02
            beamState: PAS_STATE,
            // address pasInstance.configurator
            // Argument value: 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
            configurator: PAS_CONFIGURATOR,
            // address pasInstance.timelock
            // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
            timelock: PAS_TIMELOCK
        });

        // Call PASInit.init with the following arguments
        PASInit.init(
            // Note: Use PASInstance initialised above
            pasInstance,
            // uint256 minDelay
            // Argument value: 14 days (or 1209600 seconds)
            14 days,
            // address coreCouncil
            // Argument value: 0x148eF923d764CBdc1597CcADBbbC66499C1A1432
            PAS_CORE_COUNCIL,
            // address[] cancellers
            // Argument value: []
            new address[](0),
            // address[] pausers
            // Argument value: []
            new address[](0)
        );

        // Call PASInit.addCoreToChainlog with the following arguments
        PASInit.addCoreToChainlog(
            // Note: Use DssInstance initialised above
            dss,
            // Note: Use PASInstance initialised above
            pasInstance,
            // bytes32 stateKey
            // Argument value: PAS_STATE
            "PAS_STATE",
            // bytes32 configuratorKey
            // Argument value: PAS_CONFIGURATOR
            "PAS_CONFIGURATOR",
            // bytes32 timelockKey
            // Argument value: PAS_TIMELOCK
            "PAS_TIMELOCK"
        );

        // Call PASInit.initMom with the following arguments
        PASInit.initMom(
            // Note: Use DssInstance initialised above
            dss,
            // Note: Use PASInstance initialised above
            pasInstance,
            // address mom_
            // Argument value: 0xD44B8d01D5207aA792C666d0A712A1A161CD6171
            PAS_MOM,
            // bytes32 key
            // Argument value: PAS_MOM
            "PAS_MOM"
        );

        // Note: We need to declare an array of rate limits for PAS configuration
        address[] memory rateLimits = new address[](1);
        rateLimits[0] = GROVE_RATE_LIMITS;

        // Note: We need to declare an array of controllers for PAS configuration
        address[] memory controllers = new address[](1);
        controllers[0] = GROVE_CONTROLLER;

        // Note: We need to declare an array of cBeamConfigs for PAS configuration
        InitCBeamConfig[] memory cBeamConfigs = new InitCBeamConfig[](1);
        cBeamConfigs[0] = InitCBeamConfig({
            // address cBeamConfigs[0].cBeam
            // Argument value: 0x91dC2F6DbB8Adf76d373A54D408EDd7D736046C4
            cBeam: GROVE_CBEAM,
            // address[] cBeamConfigs[0].rateLimits
            // Argument value: A single address 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1
            rateLimits: rateLimits,
            // address[] cBeamConfigs[0].controllers
            // Argument value: A single address 0xbf83F5974B932c7D842254042717D6A2706CE5eE
            controllers: controllers
        });

        // Call PASInit.initExtras with the following arguments
        PASInit.initExtras(
            // Note: Use PASInstance initialised above
            pasInstance,
            // uint256 hop
            // Argument value: 16 hours (or 57600 seconds)
            16 hours,
            // uint256 maxChange
            // Argument value: 1.20 (i.e. a maximum increase of 20% per eligible step)
            120 * WAD / 100,
            // address[] memory rateLimits
            // Argument value: A single address 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1
            rateLimits,
            // address[] memory controllers
            // Argument value: A single address 0xbf83F5974B932c7D842254042717D6A2706CE5eE
            controllers,
            // An array of cBeamConfigs with a single item
            cBeamConfigs
        );

        // Call PASInit.pauseTimelock with the following arguments
        PASInit.pauseTimelock(
            // address timelock_
            // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
            PAS_TIMELOCK,
            // address admin
            // Argument value: 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB
            MCD_PAUSE_PROXY
        );

        // ---------- Funds transfer from Ozone to SFF ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-for-transferring-funds-from-the-subproxy/28004/7
        // Atlas: https://sky-atlas.io/#9bb85c21-96a3-4f0a-baab-1c3fe340871d

        // Execute SUBPROXY_METHODS in OZONE_SUBPROXY to transfer 16 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        SubProxyLike(OZONE_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKY_FRONTIER_FOUNDATION, 16 * MILLION * WAD)
        );

        // ---------- Increase ALLOCATOR-GROVE-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-grove-for-upcoming-spell/28164/10
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-GROVE-A",
            // Increase the Maximum Debt Ceiling (line) by 15,000,000 USDS from 10,000,000 USDS to 25,000,000 USDS
            _amount: 25 * MILLION,
            // Increase the Target Available Debt (gap) by 3,000,000 USDS from 2,000,000 USDS to 5,000,000 USDS
            _gap: 5 * MILLION,
            // Leave the Ceiling Increase Cooldown (ttl) unchanged at 86,400 seconds (24 hours)
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-GROVE-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-GROVE-A");

        // ---------- Increase ALLOCATOR-PRYSM-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/aug-27-2026-osero-requested-changes-to-allocator-vault-parameters/28186
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PRYSM-A",
            // Increase the Maximum Debt Ceiling (line) by 15,000,000 USDS from 10,000,000 USDS to 25,000,000 USDS
            _amount: 25 * MILLION,
            // Increase the Target Available Debt (gap) by 3,000,000 USDS from 2,000,000 USDS to 5,000,000 USDS
            _gap: 5 * MILLION,
            // Leave the Ceiling Increase Cooldown (ttl) unchanged at 86,400 seconds (24 hours)
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-PRYSM-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-PRYSM-A");

        // ---------- Rename rewards key in Chainlog ----------
        // Forum: https://forum.skyeco.com/t/proposed-housekeeping-item-2026-08-27-executive-vote/28194
        // Atlas: https://www.sky-atlas.io/#0d0e2e1a-0502-4ee3-bc9d-8bd8ddde19ec

        // Rename OWNER_REWARDS_LSSKY_USDS to REWARDS_OWNER_LSSKY_USDS in chainlog.
        dss.chainlog.removeAddress("OWNER_REWARDS_LSSKY_USDS");
        DssExecLib.setChangelogAddress("REWARDS_OWNER_LSSKY_USDS", OWNER_REWARDS_LSSKY_USDS);

        // Note: bump chainlog version
        DssExecLib.setChangelogVersion("1.20.20");

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:1 chain: 0x38E4254bD82ED5Ee97CD1C4278FAae748d998865, 0x1A1879E66547F90bfF87D45A5b0335950E019E02, 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929, 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293, 0xD44B8d01D5207aA792C666d0A712A1A161CD6171
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a31000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078333845343235346244383245443545653937434431433432373846416165373438643939383836350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078314131383739453636353437463930626646383744343541356230333335393530453031394530320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078623745363144663643416230413531453941356461623141374444336639343264446535623932390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078423530613036416630326444453434644236454137656537323934303338343863324233353239330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30784434344238643031443532303761413739324336363664304137313241314131363143443631373100000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-spark-for-upcoming-spell/28181
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf8a0b03d3638192899495e8d85a272d78f7c61324e3f1c1f320add23ab91bda3
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x01a287ddec297d1ffe1e5c8391431fe1ee1c415e3f7e8b93d437ee9a66f29820
        // Atlas: https://sky-atlas.io/#8dd2eb27-a760-4287-89cf-7b5bdb0c5d7c
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0xbE35b15Cda9002C1719A9D254B158613BDdE72af and codehash 0xd3d82d87849aa5a7df3105bac5e97518999288f8ce91ed80c83031a058a2fcf8 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-grove-for-upcoming-spell/28164
        // Poll: https://vote.sky.money/polling/QmcTCPuC
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x04f9307629ff22e50d541658790bdfc7d8f2469ece6d1a7585145bbe3b2d4e5b
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x760f15647c7ac433a8378b07655e6ab5f48c610f9efd8a925b239f959032d6a6

        // Whitelist Grove spell with address 0xF3d4F600640a87F4203DF0A554642228a119711e and codehash 0x89f28b693c551c87c8dbd632484c39e8e5e1ac040696ed7839776ba3beae23c5 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
    }

    // ---------- Helper Functions ----------

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
