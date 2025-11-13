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

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface DssLitePsmLike {
    function kiss(address usr) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

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

    // ---------- Math ----------
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;

    // ---------- Contracts ----------
    address internal immutable DAI                       = DssExecLib.dai();
    address internal immutable MCD_LITE_PSM_USDC_A       = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable DAI_USDS                  = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal constant  NTT_MANAGER_IMP_V2        = 0xD4DD90bAC23E2a1470681E7cAfFD381FE44c3430;
    address internal constant  ALLOCATOR_OBEX_A_SUBPROXY = 0x8be042581f581E3620e29F213EA8b94afA1C8071;
    address internal constant  OBEX_ALM_PROXY            = 0xb6dD7ae22C9922AFEe0642f9Ac13e58633f715A2;

    // ---------- Spark Spell ----------
    address internal immutable SPARK_STARGUARD  = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal constant  SPARK_SPELL      = 0x63Fa202a7020e8eE0837196783f0fB768CBFE2f1;
    bytes32 internal constant  SPARK_SPELL_HASH = 0x6e88f81cc72989a637f4b87592dcde2016272fbceb08a2af3b2effdb2d20c0fb;

    // ---------- Launch Agent 4 (Obex) Spell ----------
    address internal constant OBEX_SPELL = 0xF538909eDF14d2c23002C2b3882Ad60f79d61893;

    function actions() public override {
        // ---------- Set earliest execution date November 17, 14:00 UTC ----------

        require(block.timestamp >= NOV_17_2025_14_00_UTC, "Spell can only be cast after Nov 17, 2025, 14:00 UTC");

        // ----- Solana Bridge Migration -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381
        // Poll: https://vote.sky.money/polling/Qmetv8fp
        // Forum: https://forum.sky.money/t/solana-bridge-migration/27403

        // Call MigrationInit.initMigrationStep0 with the following arguments:
        MigrationInit.initMigrationStep0({
            // nttManagerImpV2: 0xD4DD90bAC23E2a1470681E7cAfFD381FE44c3430
            nttManagerImpV2: NTT_MANAGER_IMP_V2,
            // maxFee expected to be 0 (unless Wormhole.messageFee() returns non-zero value)
            maxFee:          0,
            // payload: https://raw.githubusercontent.com/keel-fi/crosschain-gov-solana-spell-payloads/11baa180d4ad6c7579c69c8c0168e17cb73bb6ed/wh-program-upgrade-mainnet.txt
            payload:         hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc002a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a10048000000007a821ac5164fa9b54fd93b54dba8215550b8fce868f52299169f6619867cac501000106856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300012d27f5131975fdaf20a5934c6e90f6d7c9bbde9fcf94c37b48c5a49c7f06aae2000105cab222188023f74394ecaee9daf397c11a2a672511adc34958c1d7bdb1c673000106a7d517192c5c51218cc94c3d4af17f58daee089ba1fd44e3dbd98a00000000000006a7d51718c774c928566398691d5eb68b5eb8a39b4b6d5c73555b210000000000006f776e65720000000000000000000000000000000000000000000000000000000100000403000000"
        });

        // ----- Parameter Changes to Launch Agent 4 (Obex) -----
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381
        // Poll: https://vote.sky.money/polling/Qmetv8fp

        // Set the following DC-IAM Values for ALLOCATOR-OBEX-A:
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-OBEX-A",
            // Increase `gap` by 40 million USDS from 10 million USDS to 50 million
            _gap: 50 * MILLION,
            // Increase `maxLine` by 2.49 billion USDS from 10 million USDS to 2.5 billion USDS
            _amount: 2500 * MILLION,
            // Keep `ttl` unchanged at 86,400 seconds
            _ttl: 86400 seconds
        });

        // ----- Genesis Capital Transfer To Launch Agent 4 -----
        // Forum: https://forum.sky.money/t/out-of-schedule-atlas-edit-proposal/27393
        // Poll: https://vote.sky.money/polling/QmYPMN4y

        // Obex Genesis Capital Allocation - 21000000 USDS - 0x8be042581f581E3620e29F213EA8b94afA1C8071
        _transferUsds(ALLOCATOR_OBEX_A_SUBPROXY, 21_000_000 * WAD);

        // ----- Whitelist Launch Agent 4 (Obex) ALMProxy on the LitePSM -----
        // Forum: https://forum.sky.money/t/proposed-changes-to-launch-agent-4-obex-for-upcoming-spell/27370
        // Poll: https://vote.sky.money/polling/Qmetv8fp
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-03/27381

        // Whitelist Launch Agent 4 (Obex) ALMProxy at 0xb6dD7ae22C9922AFEe0642f9Ac13e58633f715A2 on the LitePSM
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(OBEX_ALM_PROXY);

        // ----- Whitelist Spark Proxy Spell in Starguard -----
        // Forum: https://forum.sky.money/t/november-13-2025-proposed-changes-to-spark-for-upcoming-spell/27354
        // Forum: https://forum.sky.money/t/november-13-2025-proposed-changes-to-sparklend-for-upcoming-spell-2/27395
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x4c705ab40a35c3c903adb87466bf563b00abc78b1d161034278d2acd74fb7621
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xd7397d29254989ce4c5785f3c67a94de21018abc4e9a76b1e7fc359aec36e60a
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x785d3b23e63e3e6b6fb7927ca0bc529b2dc7b58d429102465e4ba8a36bc23fda
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xb31a1c997c3186943b57ce9f1528cb02c1dc5399dcdc151e60d136af46d5c126
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xe697ded18a50e09618c6f34fb89cbb8358d84a4c40602928ae4b44a644b83dcf
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3

        // Whitelist the Spark Proxy Spell deployed to 0x63Fa202a7020e8eE0837196783f0fB768CBFE2f1 with codehash 0x6e88f81cc72989a637f4b87592dcde2016272fbceb08a2af3b2effdb2d20c0fb; direct execution: no in Spark Starguard
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ----- Execute Launch Agent 4 (Obex) Proxy Spell -----
        // Forum: https://forum.sky.money/t/proposed-changes-to-launch-agent-4-obex-for-upcoming-spell/27370
        // Poll: https://vote.sky.money/polling/Qmetv8fp

        // Execute the Launch Agent 4 (Obex) Proxy Spell at 0xF538909eDF14d2c23002C2b3882Ad60f79d61893
        ProxyLike(ALLOCATOR_OBEX_A_SUBPROXY).exec(OBEX_SPELL, abi.encodeWithSignature("execute()"));
    }

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
    /// @param usr The USDS receiver.
    /// @param wad The USDS amount in wad precision (10 ** 18).
    function _transferUsds(address usr, uint256 wad) internal {
        // Note: Enforce whole units to avoid rounding errors.
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
