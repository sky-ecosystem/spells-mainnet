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
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { VestAbstract } from "dss-interfaces/dss/VestAbstract.sol";
import { StarGuardInit, StarGuardConfig } from "src/dependencies/star-guard/StarGuardInit.sol";

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface StarGuardJobLike {
    function add(address starGuard) external;
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256 amount);
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/f04712408729f7074ddabb300141569d4e87068e/2025/executive-vote-2025-12-11-launch-ccea1-subproxy-and-starguard.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-12-11 MakerDAO Executive Spell | Hash: 0x13960e88b68210caa0131aa6aab1e9cd92889326cab24caa13c0f274d1bd6a40";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // Note: by the previous convention it should be a comma-separated list of DAO resolutions IPFS hashes
    string public constant dao_resolutions = "bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq";

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
    address internal immutable CHAINLOG              = DssExecLib.LOG;
    address internal immutable DAI                   = DssExecLib.dai();
    address internal immutable DAI_USDS              = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable SKY                   = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MKR_SKY               = DssExecLib.getChangelogAddress("MKR_SKY");
    address internal immutable CRON_STARGUARD_JOB    = DssExecLib.getChangelogAddress("CRON_STARGUARD_JOB");
    address internal immutable MCD_VEST_SKY_TREASURY = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable REWARDS_DIST_USDS_SKY = DssExecLib.getChangelogAddress("REWARDS_DIST_USDS_SKY");
    address internal immutable STUSDS_RATE_SETTER    = DssExecLib.getChangelogAddress("STUSDS_RATE_SETTER");
    address internal immutable SPARK_STARGUARD       = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD       = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable LOCKSTAKE_ORACLE      = DssExecLib.getChangelogAddress("LOCKSTAKE_ORACLE");

    address internal constant CCEA1_STARGUARD = 0x13D95B35248D04FB60597dd1b27BE13E73Fe0a12;

    // ---------- Wallets ----------
    address internal constant AEGIS_D                      = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
    address internal constant BLUE                         = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
    address internal constant BONAPUBLICA                  = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
    address internal constant CLOAKY_2                     = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
    address internal constant TANGO                        = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
    address internal constant SKY_STAKING                  = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Core Council Executor Agent 1 Proxy ----------
    // Note: The deployment address for the Core Council Executor Agent 1 Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-core-council-executor-agent-1-launch/27514
    address internal constant CCEA1_SUBPROXY = 0x64a2b7CfA832fE83BE6a7C1a67521B350519B9c1;

    // ---------- Spark Proxy Spell ----------
    address internal constant SPARK_PROXY_SPELL          = 0x2cB9Fa737603cB650d4919937a36EA732ACfe963;
    bytes32 internal constant SPARK_PROXY_SPELL_CODEHASH = 0x5fdec666ca088e84b1e330ce686b9b4bb84d01022c8de54529dc90cacfd56e37;

    // ---------- Grove Proxy Spell ----------
    address internal constant GROVE_PROXY_SPELL          = 0x6772d7eaaB1c2e275f46B99D8cce8d470fA790Ab;
    bytes32 internal constant GROVE_PROXY_SPELL_CODEHASH = 0x62e0ddd487406519e23c4c6e26414e898c2442dd90365ee1a4a7cb188114e614;

    function actions() public override {
        // ---------- Core Council Executor Agent 1 Launch and Funding ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-core-council-executor-agent-1-launch/27514
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-11-24/27452
        // Atlas: https://sky-atlas.io/#A.2.9.2.5.2.2

        // Initialize new StarGuard module by calling StarGuardInit.init with:
        StarGuardInit.init(
            // chainlog being DssExecLib.LOG
            CHAINLOG,
            // Note: Create StarGuardConfig with the following parameters:
            StarGuardConfig({
                // cfg.subProxy being 0x64a2b7CfA832fE83BE6a7C1a67521B350519B9c1
                subProxy: CCEA1_SUBPROXY,
                // cfg.subProxyKey being "CCEA1_SUBPROXY"
                subProxyKey: "CCEA1_SUBPROXY",
                // cfg.starGuard being 0x13D95B35248D04FB60597dd1b27BE13E73Fe0a12
                starGuard: CCEA1_STARGUARD,
                // cfg.starGuardKey being "CCEA1_STARGUARD"
                starGuardKey: "CCEA1_STARGUARD",
                // cfg.maxDelay being 7 days
                maxDelay: 7 days
            })
        );

        // Add new StarGuard module to the StarGuardJob
        // Note: This is only a subheading, actual instruction follows

        // StarGuardJobLike(CRON_STARGUARD_JOB).add(CCEA1_STARGUARD)
        StarGuardJobLike(CRON_STARGUARD_JOB).add(CCEA1_STARGUARD);

        // Transfer 20,000,000 USDS to the Core Council Executor Agent 1 SubProxy at 0x64a2b7CfA832fE83BE6a7C1a67521B350519B9c1
        _transferUsds(CCEA1_SUBPROXY, 20_000_000 * WAD);

        // Transfer 5,000,000 USDS to the Core Council Buffer Multisig at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 5_000_000 * WAD);

        // Note: Bump chainlog patch version as new keys are being added
        DssExecLib.setChangelogVersion("1.20.10");

        // ---------- Adjust USDS >> SKY Farm (Pending Forum Post) ----------
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/24
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/25
        // Atlas: https://sky-atlas.io/#A.4.3.2.1

        // VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY
        // Note: `distribute()` only needs to be called if it wasn't already, otherwise it reverts
        if (VestAbstract(MCD_VEST_SKY_TREASURY).unpaid(7) > 0) {
            VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).distribute();
        }

        // MCD_VEST_SKY_TREASURY Vest Stream  | from: 'block.timestamp' | tau: 182 days | tot: 60,297,057 SKY | usr: REWARDS_DIST_USDS_SKY
        uint256 vestId = VestAbstract(MCD_VEST_SKY_TREASURY).create(
            /* usr: */ REWARDS_DIST_USDS_SKY,
            /* tot: */ 60_297_057 * WAD,
            /* bgn: */ block.timestamp,
            /* tau: */ 182 days,
            /* eta: */ 0,
            /* mgr: */ address(0)
        );

        // res: 1 (restricted)
        VestAbstract(MCD_VEST_SKY_TREASURY).restrict(vestId);

        // Adjust the Sky allowance for MCD_VEST_SKY_TREASURY, reducing it by the remaining yanked stream amount and increasing it by the new stream total
        {
            // Note: Get the previous allowance
            uint256 pallowance = GemAbstract(SKY).allowance(address(this), MCD_VEST_SKY_TREASURY);
            // Note: Get the remaining allowance for the yanked stream
            uint256 ytot = VestAbstract(MCD_VEST_SKY_TREASURY).tot(7);
            uint256 yrxd = VestAbstract(MCD_VEST_SKY_TREASURY).rxd(7);
            uint256 yallowance = ytot - yrxd;
            // Note: Calculate the new allowance
            uint256 allowance = pallowance - yallowance + 60_297_057 * WAD;
            // Note: set the allowance
            GemAbstract(SKY).approve(MCD_VEST_SKY_TREASURY, allowance);
        }

        // Yank MCD_VEST_SKY_TREASURY vest with ID 7
        VestAbstract(MCD_VEST_SKY_TREASURY).yank(7);

        // File the new stream ID on REWARDS_DIST_USDS_SKY
        DssExecLib.setValue(REWARDS_DIST_USDS_SKY, "vestId", vestId);

        // ---------- Increase delayed upgrade penalty to 2% ----------
        // Forum: https://forum.sky.money/t/delayed-migration-penalty-update-december-11th-spell/27520
        // Atlas: https://sky-atlas.io/#A.4.1.2.1.1.1.1

        // Increase delayed upgrade penalty by 1 percentage point, from 1% to 2% fee on MKR_SKY
        DssExecLib.setValue(MKR_SKY, "fee", 2 * WAD / 100);

        // ---------- stUSDS capped OSM and Liquidation Ratio adjustments ----------
        // Forum: https://forum.sky.money/t/atlas-edit-weekly-cycle-proposal-week-of-2025-12-08/27524
        // Poll: https://vote.sky.money/polling/QmQ95c8b

        // Decrease the stUSDS Liquidation Ratio by 25%, from 145% to 120%
        DssExecLib.setIlkLiquidationRatio("LSEV2-SKY-A", 120_00);

        // Decrease the stUSDS OSM cap by 0.015 USDS, from 0.04 USDS to 0.025 USDS
        DssExecLib.setValue(LOCKSTAKE_ORACLE, "cap", 0.025 ether); // Note: ether is a keyword that represents 10**18, not the ETH token

        // Note: Poke the spotter to make the updated price immediately available
        DssExecLib.updateCollateralPrice("LSEV2-SKY-A");

        // ---------- Adjust stUSDS-BEAM Parameters ----------
        // Forum: https://forum.sky.money/t/stusds-beam-rate-setter-configuration/27161/76
        // Poll: https://vote.sky.money/polling/QmTpQ7KW

        // Increase stepStrBps by 1,000 basis points, from 500 bps to 1,500 bps
        DssExecLib.setValue(STUSDS_RATE_SETTER, "STR", "step", 1_500);

        // Increase stepDutyBps by 1,000 basis points, from 500 bps to 1,500 bps
        DssExecLib.setValue(STUSDS_RATE_SETTER, "LSEV2-SKY-A", "step", 1_500);

        // ---------- DAO Resolution for HV Bank ----------
        // Resolution: https://gateway.pinata.cloud/ipfs/bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq
        // Forum: https://forum.sky.money/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/29
        // Forum: https://forum.sky.money/t/huntingdon-valley-bank-transaction-documents-on-permaweb/16264/30

        // Approve DAO Resolution with hash bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq
        // Note: see `dao_resolutions` public variable declared above

        // ---------- Delegate Compensation for November ----------
        // Forum: https://forum.sky.money/t/november-2025-ranked-delegate-compensation/27506
        // Atlas: https://sky-atlas.io/#A.1.5

        // Transfer 4,000 USDS to AegisD at 0x78C180CF113Fe4845C325f44648b6567BC79d6E0
        _transferUsds(AEGIS_D, 4_000 * WAD);

        // Transfer 4,000 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 4_000 * WAD);

        // Transfer 4,000 USDS to Bonapublica at 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3
        _transferUsds(BONAPUBLICA, 4_000 * WAD);

        // Transfer 4,000 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 4_000 * WAD);

        // Transfer 3,788 USDS to Tango at 0xB2B86A130B1EC101e4Aed9a88502E08995760307
        _transferUsds(TANGO, 3_788 * WAD);

        // Transfer 3,027 USDS to Sky Staking at 0x05c73AE49fF0ec654496bF4008d73274a919cB5C
        _transferUsds(SKY_STAKING, 3_027 * WAD);

        // ---------- Atlas Core Development USDS Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-december-2025/27496
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 50,167 USDS to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        _transferUsds(BLUE, 50_167 * WAD);

        // Transfer 16,417 USDS to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        _transferUsds(CLOAKY_2, 16_417 * WAD);

        // ---------- Atlas Core Development SKY Payments ----------
        // Forum: https://forum.sky.money/t/atlas-core-development-payment-requests-december-2025/27496
        // Atlas: https://sky-atlas.io/#A.2.2.1.1

        // Transfer 330,000 SKY to BLUE at 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf
        GemAbstract(SKY).transfer(BLUE, 330_000 * WAD);

        // Transfer 288,000 SKY to Cloaky at 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5
        GemAbstract(SKY).transfer(CLOAKY_2, 288_000 * WAD);

        // ---------- Whitelist Spark Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/december-11-2025-proposed-changes-to-spark-for-upcoming-spell/27481
        // Atlas: https://sky-atlas.io/#A.2.9.2.2.2.5.5.1
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x1fe374e0ba506993768069bb856f91da7d854c9ea6ea9a31cc342267b79993d7
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x121b44858123a32f49d8c203ba419862f633c642ac2739030763433a8e756d61
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x2cb808bb15c7f85e6759467c715bf6bd96b1933109b7540f87dfbbcba0e57914
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x007a555d46f2c215b7d69163e763f03c3b91f31cd43dd08de88a1531631a4766
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x9b21777dfa9f7628060443a046b76a5419740f692557ef45c92f6fac1ff31801

        // Whitelist the Spark Proxy Spell deployed to 0x2cB9Fa737603cB650d4919937a36EA732ACfe963 with codehash 0x5fdec666ca088e84b1e330ce686b9b4bb84d01022c8de54529dc90cacfd56e37; direct execution: no in Spark Starguard
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_PROXY_SPELL, SPARK_PROXY_SPELL_CODEHASH);

        // ---------- Whitelist Grove Proxy Spell in Starguard ----------
        // Forum: https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.8.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.9.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.7.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.10.1.2
        // Atlas: https://sky-atlas.io/#A.6.1.1.2.2.6.1.3.1.11.1.2

        // Whitelist the Grove Proxy Spell deployed to 0x6772d7eaaB1c2e275f46B99D8cce8d470fA790Ab with codehash 0x62e0ddd487406519e23c4c6e26414e898c2442dd90365ee1a4a7cb188114e614; direct execution: no in Grove Starguard
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_PROXY_SPELL, GROVE_PROXY_SPELL_CODEHASH);
    }

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
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
