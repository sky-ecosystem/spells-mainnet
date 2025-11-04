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
// Note: code matches https://github.com/sky-ecosystem/wh-lz-migration/blob/17397879385d42521b0fe9783046b3cf25a9fec6/deploy/MigrationInit.sol
import { MigrationInit } from "src/dependencies/wh-lz-migration/MigrationInit.sol";

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-11-13 MakerDAO Executive Spell | Hash: TODO";

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

    // ---------- Contracts ----------
    address internal constant NTT_MANAGER_IMP_V2 = 0x37c618755832ef5ca44FA88BF1CCdCe46f30b479; // TODO: this needs to be newly deployed address

    // ---------- Constant Values ----------
    uint256 internal constant WH_MAX_FEE = 0;

    // ---------- Payloads ----------
    bytes internal constant WH_PROGRAM_UPGRADE_PAYLOAD = "000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc002a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a10048000000007ce0337c15d099ab89b1d402fd5877df40a09ded4856dadbdc337d510dc0661ef0001a05a61ad0a3b97c653b34dfd53fa97c7f1f69ff3211b60bc958695a45716abcf000180dcd3999cc863dc41c1d367763ae1e73d6aa9a6d126fc3ccd2011a4a2c76b1b000125f99243b1a3eae2559a3961a410ca4393d5f48ebe3f5c8d9ac5324344188477000106a7d517192c5c51218cc94c3d4af17f58daee089ba1fd44e3dbd98a00000000000006a7d51718c774c928566398691d5eb68b5eb8a39b4b6d5c73555b210000000000006f776e65720000000000000000000000000000000000000000000000000000000100000403000000";

    function actions() public override {
        // ----- Initialize migration step 0 -----
        MigrationInit.initMigrationStep0({
            nttManagerImpV2: NTT_MANAGER_IMP_V2,
            maxFee:          WH_MAX_FEE,
            payload:         WH_PROGRAM_UPGRADE_PAYLOAD
        });
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
