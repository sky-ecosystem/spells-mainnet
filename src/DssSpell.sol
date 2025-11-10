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
import {GemAbstract} from "dss-interfaces/ERC/GemAbstract.sol";
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

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface DssLitePsmLike {
    function kiss(address usr) external;
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

    // ---------- Math ----------
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;

    // ---------- Contracts ----------
    GemAbstract internal immutable DAI                       = GemAbstract(DssExecLib.dai());
    address internal immutable MCD_LITE_PSM_USDC_A           = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable DAI_USDS                      = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal constant  NTT_MANAGER_IMP_V2            = 0xD4DD90bAC23E2a1470681E7cAfFD381FE44c3430;
    address internal constant  ALLOCATOR_OBEX_A_SUBPROXY     = 0x8be042581f581E3620e29F213EA8b94afA1C8071;
    address internal constant  OBEX_ALM_PROXY                = 0xb6dD7ae22C9922AFEe0642f9Ac13e58633f715A2;

    // ---------- Constant Values ----------
    uint256 internal constant WH_MAX_FEE = 0;

    // ---------- Payloads ----------
    bytes internal constant PAYLOAD_WH_PROGRAM_UPGRADE = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc002a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a10048000000007a821ac5164fa9b54fd93b54dba8215550b8fce868f52299169f6619867cac501000106856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300012d27f5131975fdaf20a5934c6e90f6d7c9bbde9fcf94c37b48c5a49c7f06aae2000105cab222188023f74394ecaee9daf397c11a2a672511adc34958c1d7bdb1c673000106a7d517192c5c51218cc94c3d4af17f58daee089ba1fd44e3dbd98a00000000000006a7d51718c774c928566398691d5eb68b5eb8a39b4b6d5c73555b210000000000006f776e65720000000000000000000000000000000000000000000000000000000100000403000000";

    function actions() public override {
        // ----- Solana Bridge Migration -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381
        // Poll: https://vote.sky.money/polling/Qmetv8fp

        // Call MigrationInit.initMigrationStep0 with the following arguments:
        MigrationInit.initMigrationStep0({
            nttManagerImpV2: NTT_MANAGER_IMP_V2,
            maxFee:          WH_MAX_FEE,
            payload:         PAYLOAD_WH_PROGRAM_UPGRADE
        });

        // ----- Parameter Changes to Launch Agent 4 (Obex) -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381
        // Poll: https://vote.sky.money/polling/Qmetv8fp

        // Set the following DC-IAM Values for ALLOCATOR-OBEX-A:
        // gap: 50 million
        // maxLine: 2.5 billion
        // ttl: 86,400 seconds
        DssExecLib.setIlkAutoLineParameters("ALLOCATOR-OBEX-A", /* amount = */ 2500 * MILLION, /* gap = */ 50 * MILLION, /* ttl = */ 86400 seconds);

        // ----- Genesis Capital Transfer To Launch Agent 4 -----
        // Forum: https://forum.sky.money/t/out-of-schedule-atlas-edit-proposal/27393
        // Poll: https://vote.sky.money/polling/QmYPMN4y

        // Obex Genesis Capital Allocation - 21000000 USDS - 0x8be042581f581E3620e29F213EA8b94afA1C8071
        _transferUsds(ALLOCATOR_OBEX_A_SUBPROXY, 21_000_000 * WAD);

        // ----- Whitelist Launch Agent 4 (Obex) ALMProxy on the LitePSM -----
        // Forum: https://forum.sky.money/t/proposed-changes-to-launch-agent-4-obex-for-upcoming-spell/27370
        // Forum: https://forum.sky.money/t/proposed-changes-to-launch-agent-4-obex-for-upcoming-spell/27370/3

        // MCD_LITE_PSM_USDC_A.kiss(0xb6dD7ae22C9922AFEe0642f9Ac13e58633f715A2)
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(OBEX_ALM_PROXY);

        // ----- Execute Spark Proxy Spell -----

        // Execute the Spark Proxy Spell at TBD
        // TODO: Add Spark Proxy Spell code here

        // ----- Execute Grove Proxy Spell -----

        // Execute the Grove Proxy Spell at TBD
        // TODO: Add Grove Proxy Spell code here

        // ----- Execute Keel Proxy Spell -----

        // Execute the Keel Proxy Spell at TBD
        // TODO: Add Keel Proxy Spell code here

        // ----- Execute Launch Agent 4 (Obex) Proxy Spell -----

        // Execute the Launch Agent 4 (Obex) Proxy Spell at TBD
        // TODO: Add Launch Agent 4 (Obex) Proxy Spell code here
    }

    // ---------- Helper Functions ----------

    /// @notice wraps the operations required to transfer USDS from the surplus buffer.
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
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
