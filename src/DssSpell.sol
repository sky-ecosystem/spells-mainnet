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
import { DssAutoLineAbstract } from "dss-interfaces/dss/DssAutoLineAbstract.sol";

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
    string public constant override description = "2026-11-05 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant BILLION = 10 ** 9;
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD     = 10 ** 18;

    // ---------- Contracts ----------
    address internal immutable MCD_IAM_AUTO_LINE     = DssExecLib.autoLine();
    address internal immutable USDS                  = DssExecLib.getChangelogAddress("USDS");
    address internal immutable SKYBASE_SUBPROXY      = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable SUBPROXY_METHODS      = DssExecLib.getChangelogAddress("SUBPROXY_METHODS");
    address internal immutable SAFE_HARBOR_AGREEMENT = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");
    address internal immutable SPARK_STARGUARD       = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD       = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    // ---------- Wallets ----------
    address internal constant SKYBASE_FOUNDATION     = 0x58B945c8Ce34BD8cEA3Fc0437626F9F87d58A621;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL            = 0x9C3991A36aE899c7b267208bad2cC1237BE36F5b;
    bytes32 internal constant SPARK_SPELL_HASH       = 0x084497cc546ef29a5597591d820a3342a0b7687bcbd6fed504830f915a4422d9;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL            = 0xb7fdd2f1efE69EC2145A914bCEB23D48de4Bb74D;
    bytes32 internal constant GROVE_SPELL_HASH       = 0x205f19d44421f601f530310481a88bbd037f1d114e82e9cd5d82ccf828b45ee3;

    function actions() public override {
        // ----- Finalize GUSD and USDP PSM Offboarding -----

        // Finalize PSM-GUSD-A Offboarding
        // TODO

        // Finalize PSM-PAX-A Offboarding
        // TODO

        // ----- Use SUBPROXY_METHODS To Transfer USDS From SKYBASE_SUBPROXY to Skybase Foundation -----
        // Forum: https://forum.skyeco.com/t/november-5-2026-skybase-foundation-grant-900-000-usds-subproxy-transfer/28359
        // Poll: https://vote.sky.money/polling/QmYNuyHd

        // Use SUBPROXY_METHODS to transfer 900,000 USDS from SKYBASE_SUBPROXY to the Skybase Foundation (0x58B945c8Ce34BD8cEA3Fc0437626F9F87d58A621)
        SubProxyLike(SKYBASE_SUBPROXY).exec(
            SUBPROXY_METHODS,
            abi.encodeWithSelector(SubProxyMethodsLike.transfer.selector, USDS, SKYBASE_FOUNDATION, 900_000 * WAD)
        );

        // ----- Increase ALLOCATOR-SPARK-A DC-IAM ttl -----
        // Forum: https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-spark-for-upcoming-spell/28351
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Note: Action written inline with the new parameters for ALLOCATOR-SPARK-A
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-SPARK-A",
            // Leave the Maximum Debt Ceiling (line) unchanged at 10 billion USDS
            _amount: 10 * BILLION,
            // Leave the Target Available Debt (gap) unchanged at 1.5 billion USDS
            _gap: 1_500 * MILLION,
            // Increase the ALLOCATOR-SPARK-A DC-IAM ttl by 43,200 seconds from 43,200 seconds (12 hours) to 86,400 seconds (24 hours)
            _ttl: 86_400 seconds
        });

        // Note: Apply the updated ALLOCATOR-SPARK-A AutoLine configuration immediately
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-SPARK-A");

        // ----- Update Safe Harbor Agreement -----
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:8453 chain: 0x29840a8519013F483d94781b5C1671b552A109e1 (scope=0), 0x458Acd38fD749F6325039e63e8Bc496dBc286D11 (scope=0), 0x2ACADc011b4fc13072F92231D1216c16deac5188 (scope=0), 0xb22d50c393c6E1D13E3e05B172448dD8BF8DdC32 (scope=0), 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41 (scope=0),0x011A115b5498B85b3d12245A3a7296F77325B5C3 (scope=2), 0xD711DbfD937a45e2C89CA0D4781cfa5BAb32e752 (scope=2)
        calldatas[0] = hex'46c2b73400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b6569703135353a38343533000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002c00000000000000000000000000000000000000000000000000000000000000360000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078323938343061383531393031334634383364393437383162354331363731623535324131303965310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078343538416364333866443734394636333235303339653633653842633439366442633238364431310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078324143414463303131623466633133303732463932323331443132313663313664656163353138380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078623232643530633339336336453144313345336530354231373234343864443842463844644333320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078376163393631383043346436623241333238443361313961633035394430453746633343366434310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078303131413131356235343938423835623364313232343541336137323936463737333235423543330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a30784437313144626644393337613435653243383943413044343738316366613542416233326537353200000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ----- Spark Proxy Spell -----
        // Forum: https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-spark-for-upcoming-spell/28351
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x49ea98e37b49e441c62a5747225794d7351624af28e7ab3a52d18ededde95263
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xb74887a3c9d89ce3d72b97b8e10f1e2ee4588115e65755e09b3117c9e31a6ce0
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0xa0cf2d0ad428858797853eb9b015bf921e2f53a07b96aaa4de4bf28e84653298
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6

        // Whitelist Spark spell with address 0x9C3991A36aE899c7b267208bad2cC1237BE36F5b and codehash 0x084497cc546ef29a5597591d820a3342a0b7687bcbd6fed504830f915a4422d9 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ----- Grove Proxy Spell -----
        // Forum: https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-grove-for-upcoming-spell/28336
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0xa813ec78cae204f323f891b6dccdba89a6a74fb76cb612a63cd96d5332efacdb
        // Poll: https://snapshot.box/#/s:grovefinance.eth/proposal/0x5da7eb8f4101223ff240384be3cbde658b385af1f097575c761ad5839ff8c1a0
        // Atlas: https://sky-atlas.io/#aa16daa3-ee62-49eb-851e-cb0708670144

        // Whitelist Grove spell with address 0xb7fdd2f1efE69EC2145A914bCEB23D48de4Bb74D and codehash 0x205f19d44421f601f530310481a88bbd037f1d114e82e9cd5d82ccf828b45ee3 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
    }

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
