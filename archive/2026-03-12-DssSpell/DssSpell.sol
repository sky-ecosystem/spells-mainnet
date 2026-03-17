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

interface StakingRewardsLike {
    function setRewardsDuration(uint256 _rewardsDuration) external;
}

interface SafeHarborRegistryLike {
    function adoptSafeHarbor(address _agreementAddress) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/ba290bc0ad06577e0c2694d90cee0a3a1b5ec2c8/2026/executive-vote-2026-03-12-buyback-reduction-safe-harbor-adoption.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-03-12 MakerDAO Executive Spell | Hash: 0xca30bb734076b4a8dd73e61eb545d7e2445e7d57331bf1f8c16fefe0ce67de66";

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
    uint256 internal constant WAD = 10**18;
    uint256 internal constant RAD = 10**45;

    // ---------- Contracts ----------
    address internal immutable MCD_KICK           = DssExecLib.getChangelogAddress("MCD_KICK");
    address internal immutable MCD_SPLIT          = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable REWARDS_LSSKY_USDS = DssExecLib.getChangelogAddress("REWARDS_LSSKY_USDS");
    address internal immutable MKR_SKY            = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable SPARK_STARGUARD    = DssExecLib.getChangelogAddress("SPARK_STARGUARD");

    address internal constant SAFE_HARBOR_REGISTRY  = 0x326733493E143b8904716E7A64A9f4fb6A185a2c;
    address internal constant SAFE_HARBOR_AGREEMENT = 0xf17bB418B4EC251f300Aa3517Cb37349f17697A1;


    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_SPELL      = 0x9fFadcf3aFb43c1Af4Ec1D9B6B0405f1FBCf94D6;
    bytes32 internal constant SPARK_SPELL_HASH = 0xe38e933caa0aff99a63bd81b28a9cbd4d8af359c603545af5c3af9e457241733;

    function actions() public override {
        // ---------- Adjust Smart Burn Engine Parameters ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2026-03-09/27750
        // Poll: https://vote.sky.money/polling/QmRjnvHa

        // Decrease `kicker.kbump` by 4,000 USDS from 10,000 USDS to 6,000 USDS
        DssExecLib.setValue(MCD_KICK, "kbump", 6_000 * RAD);

        // Increase `splitter.hop` by 10,907 seconds from 2,880 seconds to 13,787 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 13_787);

        // Increase rewardsDuration in REWARDS_LSSKY_USDS by 10,907 seconds from 2,880 seconds to 13,787 seconds
        StakingRewardsLike(REWARDS_LSSKY_USDS).setRewardsDuration(13_787);

        // ---------- Increase delayed upgrade penalty to 3% ----------
        // Forum: https://forum.sky.money/t/delayed-migration-penalty-update-march-12th-spell/27752
        // Atlas: https://sky-atlas.io/#A.4.1.2.1.1.1.1

        // Increase delayed upgrade penalty by 1 percentage point, from 2% to 3% fee on MKR_SKY
        DssExecLib.setValue(MKR_SKY, "fee", 3_00 * WAD / 100_00);

        // ---------- Adopt Safe Harbor Agreement ----------
        // Forum: https://forum.sky.money/t/technical-scope-safe-harbor-adoption/27753
        // Atlas: https://sky-atlas.io/#A.2.11.1.2

        // Call adoptSafeHarbor on the SEAL Safe Harbor Registry with the following parameters:
        // Registry Contract: 0x326733493E143b8904716E7A64A9f4fb6A185a2c (SEAL Safe Harbor Registry)
        // Caller: 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB (Sky Pause Proxy)
        // Function: adoptSafeHarbor(address _agreement)
        // Input Argument: 0xf17bB418B4EC251f300Aa3517Cb37349f17697A1 (Deployed Sky Agreement)
        SafeHarborRegistryLike(SAFE_HARBOR_REGISTRY).adoptSafeHarbor(SAFE_HARBOR_AGREEMENT);

        // Add Agreement Contract to the Chainlog as SAFE_HARBOR_AGREEMENT
        DssExecLib.setChangelogAddress("SAFE_HARBOR_AGREEMENT", SAFE_HARBOR_AGREEMENT);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.13");

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.sky.money/t/march-12-2026-proposed-changes-to-spark-for-upcoming-spell/27741
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x9aebbe69e8555d03dc97b55475dac08225e157b3fd475d7a29848b8631627367
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xdc686a9bc77b44cb323c23dce2cc091ebd34d7876d6e1f4413786f17e0739726
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xeb2f5f08ec6ab8a2ff5302453ac7383f7519a09cf7e1e56cbb7fc8244f15cfa2
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf8c2f98cb39912a22457522c445c453b5f796f24c1886d1687dc96648ffa4c16

        // Whitelist Spark spell with address 0x9fFadcf3aFb43c1Af4Ec1D9B6B0405f1FBCf94D6 and codehash 0xe38e933caa0aff99a63bd81b28a9cbd4d8af359c603545af5c3af9e457241733 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
