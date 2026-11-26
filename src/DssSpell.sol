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

interface SubProxyMethodsLike {
    function transfer(address token, address to, uint256 amount) external;
}

interface SubProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/fe736437c4cb19dd473fcc5c5da5fbe848524c7a/2026/oos-executive-vote-2026-11-26-sff-transfer.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-11-26 MakerDAO Executive Spell | Hash: 0xffe26ab25bb11394c47df033548816db3379b383cac7ae64256ca105a1ab138a";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return false;
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
    address internal immutable USDS             = DssExecLib.getChangelogAddress("USDS");
    address internal immutable SUBPROXY_METHODS = DssExecLib.getChangelogAddress("SUBPROXY_METHODS");
    address internal immutable AMATSU_SUBPROXY  = DssExecLib.getChangelogAddress("AMATSU_SUBPROXY");
    address internal immutable OZONE_SUBPROXY   = DssExecLib.getChangelogAddress("OZONE_SUBPROXY");
    address internal immutable CCEA1_SUBPROXY   = DssExecLib.getChangelogAddress("CCEA1_SUBPROXY");

    // ---------- Wallets ----------
    address internal constant SKY_FRONTIER_FOUNDATION = 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0;

    function actions() public override {
        // ---------- Funds transfer from Agent Subproxies to SFF ----------
        // Forum: https://forum.skyeco.com/t/declaration-of-out-of-schedule-executive-vote-sky-frontier-foundation-genesis-capital/28499
        // Atlas: https://sky-atlas.io/#c9c32f24-cf6c-43d5-ac4c-bd2b4d02032b

        // Execute SUBPROXY_METHODS in AMATSU_SUBPROXY to transfer 6 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        // Atlas: https://sky-atlas.io/#06bac1e1-ae52-4c67-8ca9-0dcec22dddee
        SubProxyLike(AMATSU_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKY_FRONTIER_FOUNDATION, 6 * MILLION * WAD)
        );

        // Execute SUBPROXY_METHODS in OZONE_SUBPROXY to transfer 4 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        // Atlas: https://sky-atlas.io/#9bb85c21-96a3-4f0a-baab-1c3fe340871d
        SubProxyLike(OZONE_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKY_FRONTIER_FOUNDATION, 4 * MILLION * WAD)
        );

        // Execute SUBPROXY_METHODS in CCEA1_SUBPROXY to transfer 15 million USDS to SFF at 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0
        // Atlas: https://sky-atlas.io/#e93eb85c-a3dc-459b-8774-85c8b16dde8f
        SubProxyLike(CCEA1_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKY_FRONTIER_FOUNDATION, 15 * MILLION * WAD)
        );
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
