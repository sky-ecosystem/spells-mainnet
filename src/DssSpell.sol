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

import {DssExec} from "dss-exec-lib/DssExec.sol";
import {DssAction} from "dss-exec-lib/DssAction.sol";

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

    function actions() public override {
        // ---------- PAS Initialization ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-parallelized-allocation-system-pas-module/28188
        // Poll: https://vote.sky.money/polling/Qmas6XKB

        // Call PASInit.init with the following arguments
        // address pasInstance.beamState
        // Argument value: 0x1A1879E66547F90bfF87D45A5b0335950E019E02
        // address pasInstance.configurator
        // Argument value: 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
        // address pasInstance.timelock
        // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
        // uint256 minDelay
        // Argument value: 14 days (or 1209600 seconds)
        // address coreCouncil
        // Argument value: 0x148eF923d764CBdc1597CcADBbbC66499C1A1432
        // address[] cancellers
        // Argument value: []
        // address[] pausers
        // Argument value: []

        // Call PASInit.addCoreToChainlog with the following arguments
        // address pasInstance.beamState
        // Argument value: 0x1A1879E66547F90bfF87D45A5b0335950E019E02
        // address pasInstance.configurator
        // Argument value: 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
        // address pasInstance.timelock
        // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
        // bytes32 stateKey
        // Argument value: PAS_STATE
        // bytes32 configuratorKey
        // Argument value: PAS_CONFIGURATOR
        // bytes32 timelockKey
        // Argument value: PAS_TIMELOCK

        // Call PASInit.initMom with the following arguments
        // address pasInstance.beamState
        // Argument value: 0x1A1879E66547F90bfF87D45A5b0335950E019E02
        // address pasInstance.configurator
        // Argument value: 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
        // address pasInstance.timelock
        // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
        // address mom_
        // Argument value: 0xD44B8d01D5207aA792C666d0A712A1A161CD6171
        // bytes32 key
        // Argument value: PAS_MOM

        // Call PASInit.initExtras with the following arguments
        // address pasInstance.beamState
        // Argument value: 0x1A1879E66547F90bfF87D45A5b0335950E019E02
        // address pasInstance.configurator
        // Argument value: 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
        // address pasInstance.timelock
        // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
        // uint256 hop
        // Argument value: 16 hours (or 57600 seconds)
        // uint256 maxChange
        // Argument value: 1.20 (i.e. a maximum increase of 20% per eligible step)
        // address[] memory rateLimits
        // Argument value: A single address 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1
        // address[] memory controllers
        // Argument value: A single address 0xbf83F5974B932c7D842254042717D6A2706CE5eE
        // An array of cBeamConfigs with a single item
        // address cBeamConfigs[0].cBeam
        // Argument value: 0x91dC2F6DbB8Adf76d373A54D408EDd7D736046C4
        // address[] cBeamConfigs[0].rateLimits
        // Argument value: A single address 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1
        // address[] cBeamConfigs[0].controllers
        // Argument value: A single address 0xbf83F5974B932c7D842254042717D6A2706CE5eE

        // Call PASInit.pauseTimelock with the following arguments
        // address timelock_
        // Argument value: 0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
        // address admin
        // Argument value: 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB

        // ---------- Funds transfer from Ozone to SFF ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-for-transferring-funds-from-the-subproxy/28004/7
        // Forum: https://forum.skyeco.com/t/technical-scope-for-transferring-funds-from-the-subproxy/28004/8

        // Execute SUBPROXY_METHODS in OZONE_SUBPROXY to transfer 16 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0

        // ---------- Increase ALLOCATOR-GROVE-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-grove-for-upcoming-spell/28164/10
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase the Maximum Debt Ceiling (line) by 15,000,000 USDS from 10,000,000 USDS to 25,000,000 USDS
        // Increase the Target Available Debt (gap) by 3,000,000 USDS from 2,000,000 USDS to 5,000,000 USDS
        // Leave the Ceiling Increase Cooldown (ttl) unchanged at 86,400 seconds (24 hours)

        // ---------- Increase ALLOCATOR-PRYSM-A DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/aug-27-2026-osero-requested-changes-to-allocator-vault-parameters/28186
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase the Maximum Debt Ceiling (line) by 15,000,000 USDS from 10,000,000 USDS to 25,000,000 USDS
        // Increase the Target Available Debt (gap) by 3,000,000 USDS from 2,000,000 USDS to 5,000,000 USDS
        // Leave the Ceiling Increase Cooldown (ttl) unchanged at 86,400 seconds (24 hours)

        // ---------- Rename rewards key in chainlog ----------
        // Forum: https://forum.skyeco.com/t/proposed-housekeeping-item-2026-08-27-executive-vote/28194
        // Atlas: https://www.sky-atlas.io/#0d0e2e1a-0502-4ee3-bc9d-8bd8ddde19ec

        // Rename OWNER_REWARDS_LSSKY_USDS to REWARDS_OWNER_LSSKY_USDS in chainlog.

        // Note: bump chainlog version
        // TODO

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // TODO: add content once exec sheet is ready

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-spark-for-upcoming-spell/28181
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf8a0b03d3638192899495e8d85a272d78f7c61324e3f1c1f320add23ab91bda3
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x01a287ddec297d1ffe1e5c8391431fe1ee1c415e3f7e8b93d437ee9a66f29820
        // Atlas: https://sky-atlas.io/#8dd2eb27-a760-4287-89cf-7b5bdb0c5d7c
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0xbE35b15Cda9002C1719A9D254B158613BDdE72af and codehash 0xd3d82d87849aa5a7df3105bac5e97518999288f8ce91ed80c83031a058a2fcf8 in SPARK_STARGUARD, direct execution: No

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/august-27-2026-proposed-changes-to-grove-for-upcoming-spell/28164
        // Poll: https://vote.sky.money/polling/QmcTCPuC
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x04f9307629ff22e50d541658790bdfc7d8f2469ece6d1a7585145bbe3b2d4e5b
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x760f15647c7ac433a8378b07655e6ab5f48c610f9efd8a925b239f959032d6a6

        // Whitelist Grove spell with address 0xF3d4F600640a87F4203DF0A554642228a119711e and codehash 0x89f28b693c551c87c8dbd632484c39e8e5e1ac040696ed7839776ba3beae23c5 in GROVE_STARGUARD, direct execution: No
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
