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
import {DssExecLib} from "dss-exec-lib/DssExecLib.sol";
// Note: code matches https://github.com/sky-ecosystem/wh-lz-migration/blob/17397879385d42521b0fe9783046b3cf25a9fec6/deploy/MigrationInit.sol
import {MigrationInit} from "src/dependencies/wh-lz-migration/MigrationInit.sol";

abstract contract DssAction {

    using DssExecLib for *;

    // Modifier used to limit execution time when office hours is enabled
    modifier limited {
        require(DssExecLib.canCast(uint40(block.timestamp), officeHours()), "Outside office hours");
        _;
    }

    // Office Hours defaults to true by default.
    //   To disable office hours, override this function and
    //    return false in the inherited action.
    function officeHours() public view virtual returns (bool) {
        return true;
    }

    // DssExec calls execute. We limit this function subject to officeHours modifier.
    function execute() external limited {
        actions();
    }

    // DssAction developer must override `actions()` and place all actions to be called inside.
    //   The DssExec function will call this subject to the officeHours limiter
    //   By keeping this function public we allow simulations of `execute()` on the actions outside of the cast time.
    function actions() public virtual;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://<executive-vote-canonical-post> -q -O - 2>/dev/null)"
    function description() external view virtual returns (string memory);

    // Returns the next available cast time
    function nextCastTime(uint256 eta) external virtual view returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
    }
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-11-13 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Set earliest execution date November 17, 14:00 UTC ----------

    // Note: 2025-11-17 14:00:00 UTC
    uint256 internal constant NOV_17_2025_14_00_UTC = 1763388000;

    // Note: Override nextCastTime to inform keepers about the earliest execution time
    function nextCastTime(uint256 eta) external view override returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        // Note: First calculate the standard office hours cast time
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
        // Note: Then ensure it's not before our minimum date
        return castTime < NOV_17_2025_14_00_UTC ? NOV_17_2025_14_00_UTC : castTime;
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

    // ---------- Contracts ----------
    address internal constant NTT_MANAGER_IMP_V2 = 0xD4DD90bAC23E2a1470681E7cAfFD381FE44c3430;

    // ---------- Constant Values ----------
    uint256 internal constant WH_MAX_FEE = 0;

    // ---------- Payloads ----------
    bytes internal constant PAYLOAD_WH_PROGRAM_UPGRADE = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc002a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a10048000000007a821ac5164fa9b54fd93b54dba8215550b8fce868f52299169f6619867cac501000106856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300012d27f5131975fdaf20a5934c6e90f6d7c9bbde9fcf94c37b48c5a49c7f06aae2000105cab222188023f74394ecaee9daf397c11a2a672511adc34958c1d7bdb1c673000106a7d517192c5c51218cc94c3d4af17f58daee089ba1fd44e3dbd98a00000000000006a7d51718c774c928566398691d5eb68b5eb8a39b4b6d5c73555b210000000000006f776e65720000000000000000000000000000000000000000000000000000000100000403000000";

    function actions() public override {
        // ----- Initialize migration step 0 -----
        MigrationInit.initMigrationStep0({
            nttManagerImpV2: NTT_MANAGER_IMP_V2,
            maxFee:          WH_MAX_FEE,
            payload:         PAYLOAD_WH_PROGRAM_UPGRADE
        });
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
