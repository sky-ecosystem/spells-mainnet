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
// Note: code matches https://github.com/sky-ecosystem/wh-lz-migration/blob/17397879385d42521b0fe9783046b3cf25a9fec6/deploy/MigrationInit.sol
import { MigrationInit } from "./dependencies/wh-lz-migration/MigrationInit.sol";
// Note: code matches https://github.com/sky-ecosystem/lz-governance-relay/blob/d3e3df4db417f196fdd56123e7dbb462d04f32ef/deploy/GovernanceRelayInit.sol
import { GovernanceRelayInit } from "./dependencies/lz-governance-relay/GovernanceRelayInit.sol";

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-11-17 MakerDAO Executive Spell | Hash: TODO";

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

    // ---------- Contracts ----------
    address internal constant OFT_ADAPTER         = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;
    // base58: BEvTHkTyXooyaJzP8egDUC7WQK8cyRrq5WvERZNWhuah
    bytes32 internal constant OFT_PEER            = 0x9825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d122;
    address internal constant GOV_OAPP_SENDER     = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;
    // base58: 8vXXGiaXFrKFUDw21H5Z57ex552Lh8WP9rVd2ktzmcCy
    bytes32 internal constant GOV_PEER            = 0x75b81a4430dee7012ff31d58540835ccc89a18d1fc0522bc95df16ecd50efc32;
    address internal constant L1_GOVERNANCE_RELAY = 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61;

    // ---------- Constant Values ----------
    uint256 internal constant WH_MAX_FEE = 0;

    // ---------- Payloads ----------
    bytes internal constant PAYLOAD_TRANSFER_MINT_AUTH            = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300056f776e65720000000000000000000000000000000000000000000000000000000100b53f200f8db357f9e1e982ef0ec4b3b879f9f6516d5247307ebaf00d187be51a00009f92dcb365df21a4a4ec23d8ff4cc020cdd09895f8129c2c2fb43289bc53f95f00000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000106ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a90000002857edbb54a8aff14b8dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b";
    bytes internal constant PAYLOAD_TRANSFER_FREEZE_AUTH          = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a900020707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af00016f776e6572000000000000000000000000000000000000000000000000000000010000230601018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b";
    bytes internal constant PAYLOAD_TRANSFER_METADATA_UPDATE_AUTH = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc00b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f82946000b6f776e657200000000000000000000000000000000000000000000000000000001000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000071809dfc828921f70659869a0822bf04c42b823d518bfc11fe9a7b65d221a58f00010b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000706179657200000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000000000006a7d517187bd16635dad40455fdc2c0c124c68f215675a5dbbacb5f0800000000000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000002c3201018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b000000000000000000";

    function actions() public override {
        // ----- Solana Bridge Migration -----
        // NOTE: This is a title, the content follows below

        // ----- Call MigrationInit.initMigrationStep1 with the following parameters: -----

        MigrationInit.initMigrationStep1({
            oftAdapter: OFT_ADAPTER,
            oftPeer: OFT_PEER,
            govOapp: GOV_OAPP_SENDER,
            govPeer: GOV_PEER,
            rl: MigrationInit.RateLimitsParams({
                outboundWindow: 1 days,
                outboundLimit: 10_000_000 * WAD,
                inboundWindow: 1 days,
                inboundLimit: 10_000_000 * WAD,
                rlAccountingType: 0
            }),
            maxFee: WH_MAX_FEE,
            transferMintAuthPayload: PAYLOAD_TRANSFER_MINT_AUTH,
            transferFreezeAuthPayload: PAYLOAD_TRANSFER_FREEZE_AUTH,
            transferMetadataUpdateAuthPayload: PAYLOAD_TRANSFER_METADATA_UPDATE_AUTH
        });

        // ----- Call GovernanceRelayInit.init with the following parameters: -----

        // Note: We need dss as an input parameter for governance relay initialization
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        GovernanceRelayInit.init({
            dss: dss,
            l1GovernanceRelay: L1_GOVERNANCE_RELAY,
            l1Oapp: GOV_OAPP_SENDER
        });

        // ----- Bump chainlog PATCH version -----

        DssExecLib.setChangelogVersion("1.20.8");
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
