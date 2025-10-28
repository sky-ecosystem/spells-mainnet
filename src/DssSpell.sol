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
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
import { FlapperInit, KickerConfig } from "src/dependencies/dss-flappers/FlapperInit.sol";
import { TreasuryFundedFarmingInit, FarmingInitParams } from "src/dependencies/lockstake/TreasuryFundedFarmingInit.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface DssCronSequencerLike {
    function addJob(address job) external;
    function removeJob(address job) external;
}

interface StakingRewardsLike {
    function setRewardsDuration(uint256 duration) external;
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2025-10-30 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant RAD = 10 ** 45;

    // ---------- Contracts ----------
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable CRON_REWARDS_DIST_JOB    = DssExecLib.getChangelogAddress("CRON_REWARDS_DIST_JOB");
    address internal immutable CRON_SEQUENCER           = DssExecLib.getChangelogAddress("CRON_SEQUENCER");
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_SPLIT                = DssExecLib.getChangelogAddress("MCD_SPLIT");
    address internal immutable MCD_VEST_SKY_TREASURY    = DssExecLib.getChangelogAddress("MCD_VEST_SKY_TREASURY");
    address internal immutable LOCKSTAKE_ENGINE         = DssExecLib.getChangelogAddress("LOCKSTAKE_ENGINE");
    address internal immutable LOCKSTAKE_SKY            = DssExecLib.getChangelogAddress("LOCKSTAKE_SKY");
    address internal immutable REWARDS_LSSKY_USDS       = DssExecLib.getChangelogAddress("REWARDS_LSSKY_USDS");
    address internal immutable SKY                      = DssExecLib.getChangelogAddress("SKY");
    address internal immutable STUSDS_RATE_SETTER       = DssExecLib.getChangelogAddress("STUSDS_RATE_SETTER");

    address internal constant KICKER                    = 0xD889477102e8C4A857b78Fcc2f134535176Ec1Fc;
    address internal constant OLD_FLAP_JOB              = 0xc32506E9bB590971671b649d9B8e18CB6260559F;
    address internal constant NEW_FLAP_JOB              = 0xE564C4E237f4D7e0130FdFf6ecC8a5E931C51494;
    address internal constant REWARDS_LSSKY_SKY         = 0xB44C2Fb4181D7Cb06bdFf34A46FdFe4a259B40Fc;
    address internal constant REWARDS_DIST_LSSKY_SKY    = 0x675671A8756dDb69F7254AFB030865388Ef699Ee;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;
    address internal constant INTEGRATION_BOOST_INITIATIVE = 0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7;

    function actions() public override {
        // ---------- Initialize Kicker ----------
        // Forum: TODO

        // Init Kicker by calling FlapperInit.initKicker() with the following parameters:
        // Note: Create KickerConfig with the following parameters:
        KickerConfig memory kickerCfg = KickerConfig({
            // cfg.khump: -200 million USDS (note this is a negative value)
            khump: -200_000_000 * int256(RAD),
            // cfg.kbump: 10,000 USDS
            kbump: 100_000_000 * RAD,
            // cfg.chainlogKey: "MCD_KICK";
            chainlogKey: "MCD_KICK"
        });

        // Note: We also need dss as an input parameter for initKicker
        DssInstance memory dss = MCD.loadFromChainlog(DssExecLib.LOG);

        // Note: Call FlapperInit.initKicker with the parameters created above:
        FlapperInit.initKicker(dss, KICKER, kickerCfg);

        // Remove old FlapJob (0xc32506E9bB590971671b649d9B8e18CB6260559F) from the Sequencer
        DssCronSequencerLike(CRON_SEQUENCER).removeJob(OLD_FLAP_JOB);

        // Add new FlapJob deployed at 0xE564C4E237f4D7e0130FdFf6ecC8a5E931C51494 to the Sequencer
        DssCronSequencerLike(CRON_SEQUENCER).addJob(NEW_FLAP_JOB);

        // Update CRON_FLAP_JOB in the Chainlog to 0xE564C4E237f4D7e0130FdFf6ecC8a5E931C51494
        DssExecLib.setChangelogAddress("CRON_FLAP_JOB", NEW_FLAP_JOB);

        // ---------- Recalibrate Smart Burn Engine ----------

        // Increase splitter.burn by 75 percentage points from 25% to 100% (1 * WAD)
        DssExecLib.setValue(MCD_SPLIT, "burn", 1 * WAD);

        // Increase splitter.hop by 720 seconds from 2,160 seconds to 2,880 seconds
        DssExecLib.setValue(MCD_SPLIT, "hop", 2_880);

        // Increase rewardsDuration in REWARDS_LSSKY_USDS by 720 seconds from 2,160 seconds to 2,880 seconds
        StakingRewardsLike(REWARDS_LSSKY_USDS).setRewardsDuration(2_880);

        // ---------- Initialize lsSKY->SKY Farm ----------

        // Call TreasuryFundedFarmingInit.initLockstakeFarm with the following parameters:
        // Note: Create FarmingInitParams with the following parameters:
        FarmingInitParams memory farmingInitParams = FarmingInitParams({
            // stakingToken: LOCKSTAKE_SKY from chainlog
            stakingToken: LOCKSTAKE_SKY,
            // rewardsToken: SKY from chainlog
            rewardsToken: SKY,
            // rewards: 0xB44C2Fb4181D7Cb06bdFf34A46FdFe4a259B40Fc
            rewards: REWARDS_LSSKY_SKY,
            // rewardsKey: REWARDS_LSSKY_SKY
            rewardsKey: "REWARDS_LSSKY_SKY",
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // distKey: REWARDS_DIST_LSSKY_SKY
            distKey: "REWARDS_DIST_LSSKY_SKY",
            // distJob: CRON_REWARDS_DIST_JOB from chainlog
            distJob: CRON_REWARDS_DIST_JOB,
            // distJobInterval: 7 days - 1 hours
            distJobInterval: 7 days - 1 hours,
            // vest: MCD_VEST_SKY_TREASURY from chainlog
            vest: MCD_VEST_SKY_TREASURY,
            // vestTot: 1,000,000,000 SKY
            vestTot: 1_000_000_000 * WAD,
            // vestBgn: block.timestamp - 7 days
            vestBgn: block.timestamp - 7 days,
            // vestTau: 180 days
            vestTau: 180 days
        });

        // Note: Call TreasuryFundedFarmingInit.initLockstakeFarm with the parameters created above:
        TreasuryFundedFarmingInit.initLockstakeFarm(farmingInitParams, LOCKSTAKE_ENGINE);

        // ---------- Initialize Spark StarGuard ----------

        // Call StarGuardInit.init with the following parameters:

        // address chainlog: DssExecLib.LOG

        // cfg.subProxy: 0x3300f198988e4C9C63F75dF86De36421f06af8c4

        // cfg.subProxyKey: SPARK_SUBPROXY

        // cfg.starGuard: 0x6605aa120fe8b656482903E7757BaBF56947E45E

        // cfg.starGuardKey: SPARK_STARGUARD

        // cfg.maxDelay: 7 days

        // Add StarGuardJob deployed at 0xB18d211fA69422a9A848B790C5B4a3957F7Aa44E to the Sequencer

        // Add SPARK_STARGUARD to the StarGuardJob

        // Add StarGuardJob to the Chainlog as CRON_STARGUARD_JOB

        // ---------- Fund Core Council Multisigs ----------

        // Transfer 3,876,387 USDS to the Core Council Budget Multisig at 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364

        // Transfer 193,820 USDS to the Core Council Delegate Multisig at 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3

        // ---------- Fund Integration Boost Multisig ----------

        // Transfer 1,000,000 USDS to 0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7

        // ---------- Adjust stUSDS Beam step parameters ----------

        // Reduce str step parameter by 3,500 bps from 4,000 bps to 500 bps
        DssExecLib.setValue(STUSDS_RATE_SETTER, "STR", "step", 500);

        // Reduce duty step parameter by 3,500 bps from 4,000 bps to 500 bps
        DssExecLib.setValue(STUSDS_RATE_SETTER, "LSEV2-SKY-A", "step", 500);

        // Maintain all other parameters at their current values
        // Note: no actions required

        // ---------- Execute Spark Proxy Spell ----------
        // Forum: TODO
        // Poll: TODO

        // Execute the Spark Proxy Spell at 0x71059EaAb41D6fda3e916bC9D76cB44E96818654
        // ProxyLike(SPARK_PROXY).exec(SPARK_SPELL, abi.encodeWithSignature("execute()"));

        // ---------- Execute Bloom/Grove Proxy Spell ----------
        // Forum: TODO
        // Poll: TODO

        // Execute the Bloom/Grove Proxy Spell at 0x8b4A92f8375ef89165AeF4639E640e077d7C656b
        // ProxyLike(BLOOM_PROXY).exec(BLOOM_SPELL, abi.encodeWithSignature("execute()"));
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
