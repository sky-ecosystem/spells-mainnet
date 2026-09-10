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

pragma solidity ^0.8.16;

import {StakingRewardsInit, StakingRewardsInitParams} from "../StakingRewardsInit.sol";
import {VestInit, VestCreateParams} from "../VestInit.sol";
import {VestedRewardsDistributionInit, VestedRewardsDistributionInitParams} from "../VestedRewardsDistributionInit.sol";

struct FarmingInitParams {
    address stakingToken;
    address rewardsToken;
    address rewards;
    bytes32 rewardsKey; // Chainlog key
    address dist;
    bytes32 distKey; // Chainlog key
    address distJob;
    uint256 distJobInterval; // in seconds
    address vest;
    uint256 vestTot; // wad
    uint256 vestBgn; // unix timestamp
    uint256 vestTau; // in seconds
}

struct FarmingInitResult {
    uint256 vestId;
    uint256 distributedAmount;
}

struct FarmingUpdateVestParams {
    address dist;
    uint256 vestTot;
    uint256 vestBgn;
    uint256 vestTau;
}

struct FarmingUpdateVestResult {
    uint256 prevVestId;
    uint256 prevDistributedAmount;
    uint256 vestId;
    uint256 distributedAmount;
}

library TreasuryFundedFarmingInit {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function initFarm(FarmingInitParams memory p) internal returns (FarmingInitResult memory r) {
        DssVestTransferrableLike vest = DssVestTransferrableLike(p.vest);
        // Note: `p.vest` is expected to be of type `DssVestTransferrable`
        require(vest.czar() == address(this), "initFarm/vest-czar-mismatch");
        require(vest.gem() == p.rewardsToken, "initFarm/vest-gem-mismatch");

        StakingRewardsLike rewards = StakingRewardsLike(p.rewards);
        require(rewards.stakingToken() == p.stakingToken, "initFarm/rewards-staking-token-mismatch");
        require(rewards.rewardsToken() == p.rewardsToken, "initFarm/rewards-rewards-token-mismatch");
        require(rewards.rewardRate() == 0, "initFarm/reward-rate-not-zero");
        require(rewards.rewardsDistribution() == address(0), "initFarm/rewards-distribution-already-set");
        require(rewards.owner() == address(this), "initFarm/invalid-owner");

        VestedRewardsDistributionLike dist = VestedRewardsDistributionLike(p.dist);
        require(dist.gem() == p.rewardsToken, "initFarm/dist-gem-mismatch");
        require(dist.dssVest() == p.vest, "initFarm/dist-dss-vest-mismatch");
        require(dist.vestId() == 0, "initFarm/dist-vest-id-already-set");
        require(dist.stakingRewards() == p.rewards, "initFarm/dist-staking-rewards-mismatch");

        // Set `dist` with `rewardsDistribution` role in `rewards`.
        StakingRewardsInit.init(p.rewards, StakingRewardsInitParams({dist: p.dist}));

        ERC20Like rewardsToken = ERC20Like(p.rewardsToken);
        // Increase `rewardsToken` `p.vest` allowance from the treasury for `p.vestTot`.
        uint256 allowance = rewardsToken.allowance(address(this), p.vest);
        rewardsToken.approve(p.vest, allowance + p.vestTot);

        // Check if `p.vest.cap` needs to be adjusted based on the new vest rate.
        // Note: adds 10% buffer to the rate, as usual for this parameter.
        uint256 cap = vest.cap();
        uint256 rateWithBuffer = (110 * p.vestTot) / (100 * p.vestTau);
        if (rateWithBuffer > cap) {
            vest.file("cap", rateWithBuffer);
        }

        // Create the proper vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            p.vest, VestCreateParams({usr: p.dist, tot: p.vestTot, bgn: p.vestBgn, tau: p.vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        // Check if the first distribution is already available and then distribute.
        uint256 unpaid = vest.unpaid(vestId);
        if (unpaid > 0) {
            dist.distribute();
        }

        VestedRewardsDistributionJobLike distJob = VestedRewardsDistributionJobLike(p.distJob);
        distJob.set(p.dist, p.distJobInterval);

        r.vestId = vestId;
        r.distributedAmount = unpaid;

        chainlog.setAddress(p.rewardsKey, p.rewards);
        chainlog.setAddress(p.distKey, p.dist);
    }

    function initLockstakeFarm(FarmingInitParams memory p, address lockstakeEngine)
        internal
        returns (FarmingInitResult memory r)
    {
        address lssky = LockstakeEngineLike(lockstakeEngine).lssky();
        require(p.stakingToken == lssky, "initLockstakeFarm/staking-token-not-lssky");
        r = initFarm(p);
        LockstakeEngineLike(lockstakeEngine).addFarm(p.rewards);
    }

    function updateFarmVest(FarmingUpdateVestParams memory p) internal returns (FarmingUpdateVestResult memory r) {
        require(p.vestTot > 0, "updateFarmVest/vest-tot-zero");
        require(p.vestTau > 0, "updateFarmVest/vest-tau-zero");

        VestedRewardsDistributionLike dist = VestedRewardsDistributionLike(p.dist);
        require(dist.vestId() != 0, "updateFarmVest/dist-vest-id-not-set");

        DssVestTransferrableLike vest = DssVestTransferrableLike(dist.dssVest());
        // Note: `vest` is expected to be of type `DssVestTransferrable`
        require(vest.czar() == address(this), "updateFarmVest/vest-czar-mismatch");
        require(vest.gem() == dist.gem(), "updateFarmVest/vest-gem-mismatch");

        ERC20Like rewardsToken = ERC20Like(dist.gem());
        uint256 prevVestId = dist.vestId();

        // Check if there is a distribution to be done in the previous vesting stream.
        uint256 prevUnpaid = vest.unpaid(prevVestId);
        if (prevUnpaid > 0) {
            dist.distribute();
        }

        // Adjust allowance for the new vest
        {
            uint256 currAllowance = rewardsToken.allowance(address(this), address(vest));
            uint256 prevVestTot = vest.tot(prevVestId);
            uint256 prevVestRxd = vest.rxd(prevVestId);
            rewardsToken.approve(address(vest), currAllowance + p.vestTot - (prevVestTot - prevVestRxd));
        }

        // Yank the previous vesting stream.
        vest.yank(prevVestId);

        // Check if vest cap needs adjustment
        {
            uint256 cap = vest.cap();
            uint256 rateWithBuffer = (110 * p.vestTot) / (100 * p.vestTau);
            if (rateWithBuffer > cap) {
                vest.file("cap", rateWithBuffer);
            }
        }

        // Create a new vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            address(vest), VestCreateParams({usr: p.dist, tot: p.vestTot, bgn: p.vestBgn, tau: p.vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        // Check if the first distribution is already available and then distribute.
        uint256 unpaid = vest.unpaid(vestId);
        if (unpaid > 0) {
            dist.distribute();
        }

        r.prevVestId = prevVestId;
        r.prevDistributedAmount = prevUnpaid;
        r.vestId = vestId;
        r.distributedAmount = unpaid;
    }
}

interface DssVestTransferrableLike {
    function cap() external view returns (uint256);
    function czar() external view returns (address);
    function gem() external view returns (address);
    function file(bytes32 key, uint256 value) external;
    function rxd(uint256 vestId) external view returns (uint256);
    function tot(uint256 vestId) external view returns (uint256);
    function unpaid(uint256 vestId) external view returns (uint256);
    function yank(uint256 vestId) external;
}

interface StakingRewardsLike {
    function owner() external view returns (address);
    function rewardRate() external view returns (uint256);
    function rewardsDistribution() external view returns (address);
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);
}

interface VestedRewardsDistributionLike {
    function dssVest() external view returns (address);
    function distribute() external;
    function gem() external view returns (address);
    function stakingRewards() external view returns (address);
    function vestId() external view returns (uint256);
}

interface ChainlogLike {
    function setAddress(bytes32 key, address addr) external;
}

interface ERC20Like {
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
}

interface VestedRewardsDistributionJobLike {
    function set(address dist, uint256 interval) external;
}

interface LockstakeEngineLike {
    function addFarm(address farm) external;
    function lssky() external view returns (address);
}
