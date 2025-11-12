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
    address internal constant USDS_OFT        = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;
    // Note: base58 BEvTHkTyXooyaJzP8egDUC7WQK8cyRrq5WvERZNWhuah to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=BEvTHkTyXooyaJzP8egDUC7WQK8cyRrq5WvERZNWhuah&output_type=hex
    bytes32 internal constant SOLANA_USDS_OFT = 0x9825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d122;
    address internal constant LZ_GOV_SENDER   = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;
    // Note: base58 8vXXGiaXFrKFUDw21H5Z57ex552Lh8WP9rVd2ktzmcCy to hex conversion can be checked at https://emn178.github.io/online-tools/base58/decode/?input=8vXXGiaXFrKFUDw21H5Z57ex552Lh8WP9rVd2ktzmcCy&output_type=hex
    bytes32 internal constant SOLANA_LZ_GOV   = 0x75b81a4430dee7012ff31d58540835ccc89a18d1fc0522bc95df16ecd50efc32;
    address internal constant LZ_GOV_RELAY    = 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61;

    function actions() public override {
        // ----- Solana Bridge Migration -----
        // Note: This is heading, the content is below.

        // ----- Call MigrationInit.initMigrationStep1 with the following parameters: -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381
        // Poll: https://vote.sky.money/polling/Qmetv8fp
        // Forum: https://forum.sky.money/t/solana-bridge-migration/27403

        MigrationInit.initMigrationStep1({
            // oftAdapter – 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8
            oftAdapter: USDS_OFT,
            // oftPeer – BEvTHkTyXooyaJzP8egDUC7WQK8cyRrq5WvERZNWhuah
            oftPeer: SOLANA_USDS_OFT,
            // govOapp – 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA
            govOapp: LZ_GOV_SENDER,
            // govPeer – 8vXXGiaXFrKFUDw21H5Z57ex552Lh8WP9rVd2ktzmcCy
            govPeer: SOLANA_LZ_GOV,
            rl: MigrationInit.RateLimitsParams({
                // rl.outboundWindow: 1 days
                outboundWindow: 1 days,
                // rl.outboundLimit: 10,000,000 USDS
                outboundLimit: 10_000_000 * WAD,
                // rl.inboundWindow: 1 days
                inboundWindow: 1 days,
                // rl.inboundLimit: 10,000,000 USDS
                inboundLimit: 10_000_000 * WAD,
                // rl.rlAccountingType: 0 (Net)
                rlAccountingType: 0
            }),
            // maxFee expected to be 0 (unless Wormhole.messageFee() returns non-zero value)
            maxFee: 0,
            // transferMintAuthPayload: https://raw.githubusercontent.com/keel-fi/crosschain-gov-solana-spell-payloads/11baa180d4ad6c7579c69c8c0168e17cb73bb6ed/ntt-transfer-mint-authority-mainnet.txt
            transferMintAuthPayload: hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300056f776e65720000000000000000000000000000000000000000000000000000000100b53f200f8db357f9e1e982ef0ec4b3b879f9f6516d5247307ebaf00d187be51a00009f92dcb365df21a4a4ec23d8ff4cc020cdd09895f8129c2c2fb43289bc53f95f00000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000106ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a90000002857edbb54a8aff14b9825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d122",
            // transferFreezeAuthPayload: https://raw.githubusercontent.com/keel-fi/crosschain-gov-solana-spell-payloads/b108b90e24e71c3d82dfde9599ce44dda913683a/set-token-freeze-authority-mainnet.txt
            transferFreezeAuthPayload: hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a900020707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af00016f776e6572000000000000000000000000000000000000000000000000000000010000230601018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b",
            // transferMetadataUpdateAuthPayload: https://raw.githubusercontent.com/keel-fi/crosschain-gov-solana-spell-payloads/b108b90e24e71c3d82dfde9599ce44dda913683a/update-mpl-metadata-authority-mainnet.txt
            transferMetadataUpdateAuthPayload: hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc00b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f82946000b6f776e657200000000000000000000000000000000000000000000000000000001000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000071809dfc828921f70659869a0822bf04c42b823d518bfc11fe9a7b65d221a58f00010b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000706179657200000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000000000006a7d517187bd16635dad40455fdc2c0c124c68f215675a5dbbacb5f0800000000000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000002c3201018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b000000000000000000"
        });

        // ----- Call GovernanceRelayInit.init with the following parameters: -----

        GovernanceRelayInit.init({
            // Note: We need dss as an input parameter for governance relay initialization
            dss: MCD.loadFromChainlog(DssExecLib.LOG),
            // l1GovernanceRelay – 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61
            l1GovernanceRelay: LZ_GOV_RELAY,
            // l1Oapp – 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA
            l1Oapp: LZ_GOV_SENDER
        });

        // ----- Add new SkyOFTAdapter to chainlog as USDS_OFT -----

        DssExecLib.setChangelogAddress('USDS_OFT', USDS_OFT);

        // ----- Add new GovernanceOAppSender to chainlog as LZ_GOV_SENDER -----

        DssExecLib.setChangelogAddress('LZ_GOV_SENDER', LZ_GOV_SENDER);

        // ----- Bump chainlog PATCH version -----

        DssExecLib.setChangelogVersion("1.20.8");
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
