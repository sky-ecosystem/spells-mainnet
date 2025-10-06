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
import {MCD} from "dss-test/MCD.sol";
import {GemAbstract} from "dss-interfaces/ERC/GemAbstract.sol";
import {VestAbstract} from "dss-interfaces/dss/VestAbstract.sol";
import {LockstakeInit} from "./dependencies/lockstake/LockstakeInit.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256 amount);
}

interface DssLitePsmLike {
    function kiss(address usr) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/071f7daed43a2912d719ef1e3d120eda34da38ba/2025/executive-vote-2025-10-06-lockstake-capped-osm-wrapper.md' -q -O - 2>/dev/null)"
    string public constant override description = "2025-10-06 MakerDAO Executive Spell | Hash: 0x10f017865614b5e43a28e0422cb15c0b27add62242b25f99e522633e0f157e4a";

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
    address internal immutable MCD_VEST_SKY_TREASURY = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable REWARDS_DIST_USDS_SKY = DssExecLib.getChangelogAddress("REWARDS_DIST_USDS_SKY");
    address internal immutable SKY                   = DssExecLib.getChangelogAddress("SKY");
    address internal immutable MCD_LITE_PSM_USDC_A   = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");

    address internal constant LOCKSTAKE_ORACLE = 0x0C13fF3DC02E85aC169c4099C09c9B388f2943Fd;
    address internal constant NOVA_ALM_PROXY   = 0xa5139956eC99aE2e51eA39d0b57C42B6D8db0758;

    // ---------- Spark Proxy Spell ----------
    // Note: Spark Proxy: https://github.com/sparkdotfi/sparklend-deployments/blob/bba4c57d54deb6a14490b897c12a949aa035a99b/script/output/1/primary-sce-latest.json#L2
    address internal constant SPARK_PROXY = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address internal constant SPARK_SPELL = 0x4a3a40957CDc47552E2BE2012d127A5f4BD7f689;

    // ---------- Bloom/Grove Proxy ----------
    // Note: The deployment address for the Grove Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-star-2-allocator-launch/26190
    address internal constant BLOOM_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;
    address internal constant BLOOM_SPELL = 0x67e7b3bFAb1Fb6267baECEc034Bbf7592F6B4E9b;

    // ---------- Nova/Keel Proxy ----------
    // Note: The deployment address of the Nova Proxy can be found at https://forum.sky.money/t/technical-scope-of-the-nova-allocator-adjustment/27175
    address internal constant NOVA_PROXY = 0x355CD90Ecb1b409Fdf8b64c4473C3B858dA2c310;
    address internal constant NOVA_SPELL = 0x7ae136b7e677C6A9B909a0ef0a4E29f0a1c3c7fE;

    function actions() public override {
        // ---------- Launch Lockstake Capped OSM Wrapper ----------
        // Forum: https://forum.sky.money/t/technical-scope-of-the-lockstake-capped-osm-wrapper-launch/27246
        // Forum: https://forum.sky.money/t/technical-scope-of-the-lockstake-capped-osm-wrapper-launch/27246/4

        // Update to Lockstake Capped OSM Wrapper by calling LockstakeInit.updateOSM with the following parameters:
        LockstakeInit.updateOsm(
            // dss: A DssInstance (from dss-test/MCD.sol)
            MCD.loadFromChainlog(DssExecLib.LOG),
            // cappedOSM: 0x0C13fF3DC02E85aC169c4099C09c9B388f2943Fd
            LOCKSTAKE_ORACLE,
            // cap: 0.04 USDS
            // Note: ether is a keyword that represents 10**18, not the ETH token
            0.04 ether
        );

        // Note: Bump chainlog PATCH version
        DssExecLib.setChangelogVersion("1.20.5");

        // ---------- SKY Token Rewards Rebalance ----------
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/19
        // Forum: https://forum.sky.money/t/sky-token-rewards-usds-to-sky-rewards-normalization-configuration/26638/20
	    // Atlas: https://sky-atlas.powerhouse.io/A.4.3.2.1_SKY_Token_Rewards/1d6f2ff0-8d73-809b-9088-d11181182d17%7Cb3417d54eb16

        // VestedRewardsDistribution.distribute() on REWARDS_DIST_USDS_SKY
        // Note: `distribute()` only needs to be called if it wasn't already, otherwise it reverts
        if (VestAbstract(MCD_VEST_SKY_TREASURY).unpaid(6) > 0) {
            VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).distribute();
        }

        // MCD_VEST_SKY_TREASURY Vest Stream  | from: 'block.timestamp' | tau: 182 days | tot: 68,379,376 SKY | usr: REWARDS_DIST_USDS_SKY
        uint256 vestId = VestAbstract(MCD_VEST_SKY_TREASURY).create(
            /* usr: */ REWARDS_DIST_USDS_SKY,
            /* tot: */ 68_379_376 * WAD,
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
            uint256 ytot = VestAbstract(MCD_VEST_SKY_TREASURY).tot(6);
            uint256 yrxd = VestAbstract(MCD_VEST_SKY_TREASURY).rxd(6);
            uint256 yallowance = ytot - yrxd;
            // Note: Calculate the new allowance
            uint256 allowance = pallowance - yallowance + 68_379_376 * WAD;
            // Note: set the allowance
            GemAbstract(SKY).approve(MCD_VEST_SKY_TREASURY, allowance);
        }

        // Yank MCD_VEST_SKY_TREASURY vest with ID 6
        VestAbstract(MCD_VEST_SKY_TREASURY).yank(6);

        // File the new stream ID on REWARDS_DIST_USDS_SKY
        DssExecLib.setValue(REWARDS_DIST_USDS_SKY, "vestId", vestId);

        // ---------- Kiss Nova/Keel ALM Proxy on litePSM ----------
        // Forum: https://forum.sky.money/t/october-02-2025-prime-technical-scope-keel-initialization-for-upcoming-spell/27192
        // Poll: https://vote.sky.money/polling/QmWfqZRS

        // Whitelist Nova/Keel ALMProxy at 0xa5139956eC99aE2e51eA39d0b57C42B6D8db0758 on MCD_LITE_PSM_USDC_A
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(NOVA_ALM_PROXY);

        // ---------- Spark Spell ----------
        // Forum: https://forum.sky.money/t/october-2-2025-proposed-changes-to-spark-for-upcoming-spell/27191
        // Atlas: https://sky-atlas.powerhouse.io/A.2.9.1.1.2.9.1_Revenue_Share/248f2ff0-8d73-8039-a678-ce5cefe826d0|9e1f80092582d098de0cf76e
        // Atlas: https://sky-atlas.powerhouse.io/A.AG1.3.2.1.2.1_SparkLend_Risk_Parameters_Modification/1c1f2ff0-8d73-819c-9641-d87ad5b7058b|7896ed3326389fe3553030cd0a822213
        // Poll: https://vote.sky.money/polling/QmcuRr3c
        // Poll: https://vote.sky.money/polling/QmdY24Cm
        // Poll: https://vote.sky.money/polling/QmeKTbg6
        // Poll: https://vote.sky.money/polling/QmerdKkX
        // Poll: https://vote.sky.money/polling/QmREvn1i
        // Poll: https://vote.sky.money/polling/QmSaMJWy
        // Poll: https://vote.sky.money/polling/QmUn84ag
        // Poll: https://vote.sky.money/polling/QmXYRjmQ

        // Approve Spark proxy spell with address 0x4a3a40957CDc47552E2BE2012d127A5f4BD7f689
        ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));

        // ---------- Bloom/Grove Spell ----------
        // Forum: https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        // Poll: https://vote.sky.money/polling/QmPsHirj
        // Poll: https://vote.sky.money/polling/QmTE1YTn

        // Approve Bloom/Grove proxy spell with address 0x67e7b3bFAb1Fb6267baECEc034Bbf7592F6B4E9b
        ProxyLike(BLOOM_PROXY).exec(BLOOM_SPELL, abi.encodeWithSignature("execute()"));

        // ---------- Nova/Keel Spell ----------
        // Forum: https://forum.sky.money/t/october-02-2025-prime-technical-scope-keel-initialization-for-upcoming-spell/27192
        // Poll: https://vote.sky.money/polling/QmWfqZRS

        // Approve Nova/Keel proxy spell with address 0x7ae136b7e677C6A9B909a0ef0a4E29f0a1c3c7fE
        ProxyLike(NOVA_PROXY).exec(NOVA_SPELL, abi.encodeWithSignature("execute()"));
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
