// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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

pragma solidity >=0.8.0;

import { DssInstance } from "dss-test/MCD.sol";
import { SplitterInstance } from "./SplitterInstance.sol";

interface FlapperUniV2Like {
    function pip() external view returns (address);
    function spotter() external view returns (address);
    function usds() external view returns (address);
    function gem() external view returns (address);
    function receiver() external view returns (address);
    function pair() external view returns (address);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
}

interface SplitterMomLike {
    function splitter() external view returns (address);
    function setAuthority(address) external;
}

interface OracleWrapperLike {
    function pip() external view returns (address);
    function divisor() external view returns (uint256);
}

interface PipLike {
    function kiss(address) external;
}

interface PairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface UsdsJoinLike {
    function usds() external view returns (address);
}

interface SplitterLike {
    function live() external view returns (uint256);
    function vat() external view returns (address);
    function usdsJoin() external view returns (address);
    function hop() external view returns (uint256);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
}

interface FarmLike {
    function rewardsToken() external view returns (address);
    function setRewardsDistribution(address) external;
    function setRewardsDuration(uint256) external;
}

interface KickerLike {
    function vat() external view returns (address);
    function vow() external view returns (address);
    function splitter() external view returns (address);
    function file(bytes32, uint256) external;
    function file(bytes32, int256) external;
}

struct FlapperUniV2Config {
    uint256 want;
    address pip;
    address pair;
    address usds;
    address splitter;
    bytes32 prevChainlogKey;
    bytes32 chainlogKey;
}

struct FarmConfig {
    address splitter;
    address usdsJoin;
    uint256 hop;
    bytes32 prevChainlogKey;
    bytes32 chainlogKey;
}

struct SplitterConfig {
    uint256 hump;
    uint256 bump;
    uint256 hop;
    uint256 burn;
    address usdsJoin;
    bytes32 splitterChainlogKey;
    bytes32 prevMomChainlogKey;
    bytes32 momChainlogKey;
}

struct KickerConfig {
    int256  khump;
    uint256 kbump;
    bytes32 chainlogKey;
}

library FlapperInit {
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    function initFlapperUniV2(
        DssInstance        memory dss,
        address                   flapper_,
        FlapperUniV2Config memory cfg
    ) internal {
        FlapperUniV2Like flapper = FlapperUniV2Like(flapper_);

        // Sanity checks
        require(flapper.spotter()  == address(dss.spotter),                       "Flapper spotter mismatch");
        require(flapper.usds()     == cfg.usds,                                   "Flapper usds mismatch");
        require(flapper.pair()     == cfg.pair,                                   "Flapper pair mismatch");
        require(flapper.receiver() == dss.chainlog.getAddress("MCD_PAUSE_PROXY"), "Flapper receiver mismatch");

        PairLike pair = PairLike(flapper.pair());
        (address pairUsds, address pairGem) = pair.token0() == cfg.usds ? (pair.token0(), pair.token1())
                                                                        : (pair.token1(), pair.token0());
        require(pairUsds == cfg.usds,      "Usds mismatch");
        require(pairGem  == flapper.gem(), "Gem mismatch");

        require(cfg.want >= WAD * 90 / 100, "want too low");

        flapper.file("want", cfg.want);
        flapper.file("pip",  cfg.pip);
        flapper.rely(cfg.splitter);

        SplitterLike(cfg.splitter).file("flapper", flapper_);

        if (cfg.prevChainlogKey != bytes32(0)) dss.chainlog.removeAddress(cfg.prevChainlogKey);
        dss.chainlog.setAddress(cfg.chainlogKey, flapper_);
    }

    function initDirectOracle(address flapper) internal {
        PipLike(FlapperUniV2Like(flapper).pip()).kiss(flapper);
    }

    function initOracleWrapper(
        DssInstance memory dss,
        address wrapper_,
        uint256 divisor,
        bytes32 clKey
    ) internal {
        OracleWrapperLike wrapper = OracleWrapperLike(wrapper_);
        require(wrapper.divisor() == divisor, "Wrapper divisor mismatch"); // Sanity check
        PipLike(wrapper.pip()).kiss(wrapper_);
        dss.chainlog.setAddress(clKey, wrapper_);
    }

    function setFarm(
        DssInstance memory dss,
        address            farm_,
        FarmConfig  memory cfg
    ) internal {
        FarmLike     farm     = FarmLike(farm_);
        SplitterLike splitter = SplitterLike(cfg.splitter);

        require(farm.rewardsToken() == UsdsJoinLike(cfg.usdsJoin).usds(), "Farm rewards not usds");
        // Staking token is checked in the Lockstake script

        // The following two checks enforce the initSplitter function has to be called first
        require(cfg.hop >= 5 minutes, "hop too low");
        require(cfg.hop == splitter.hop(), "hop mismatch");

        splitter.file("farm", farm_);

        farm.setRewardsDistribution(cfg.splitter);
        farm.setRewardsDuration(cfg.hop);

        if (cfg.prevChainlogKey != bytes32(0)) dss.chainlog.removeAddress(cfg.prevChainlogKey);
        dss.chainlog.setAddress(cfg.chainlogKey, farm_);
    }

    function initSplitter(
        DssInstance      memory dss,
        SplitterInstance memory splitterInstance,
        SplitterConfig   memory cfg
    ) internal {
        SplitterLike    splitter = SplitterLike(splitterInstance.splitter);
        SplitterMomLike mom      = SplitterMomLike(splitterInstance.mom);

        // Sanity checks
        require(splitter.live()     == 1,                              "Splitter not live");
        require(splitter.vat()      == address(dss.vat),               "Splitter vat mismatch");
        require(splitter.usdsJoin() == cfg.usdsJoin,                   "Splitter usdsJoin mismatch");
        require(mom.splitter()      == splitterInstance.splitter,      "Mom splitter mismatch");

        require(cfg.hump > 0,         "hump too low");
        require(cfg.bump % RAY == 0,  "bump not multiple of RAY");
        require(cfg.hop >= 5 minutes, "hop too low");
        require(cfg.burn <= WAD,      "burn too high");

        splitter.file("hop",  cfg.hop);
        splitter.file("burn", cfg.burn);
        splitter.rely(address(mom));
        splitter.rely(address(dss.vow));

        dss.vow.file("flapper", splitterInstance.splitter);
        dss.vow.file("hump", cfg.hump);
        dss.vow.file("bump", cfg.bump);

        mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        dss.chainlog.setAddress(cfg.splitterChainlogKey, splitterInstance.splitter);
        if (cfg.prevMomChainlogKey != bytes32(0)) dss.chainlog.removeAddress(cfg.prevMomChainlogKey);
        dss.chainlog.setAddress(cfg.momChainlogKey, address(mom));
    }

    function initKicker(
        DssInstance  memory dss,
        address             kicker,
        KickerConfig memory cfg
    ) internal {
        require(cfg.kbump % RAY == 0,  "kbump not multiple of RAY");

        address splitter = dss.chainlog.getAddress("MCD_SPLIT");
        require(KickerLike(kicker).vow() == address(dss.vow), "vow mismatch");
        require(KickerLike(kicker).splitter() == splitter, "splitter mismatch");

        dss.vow.file("bump", 0);
        dss.vow.file("hump", type(uint256).max);
        dss.vow.file("dump", 0);
        dss.vow.file("sump", type(uint256).max);

        KickerLike(kicker).file("khump", cfg.khump);
        KickerLike(kicker).file("kbump", cfg.kbump);

        dss.vat.rely(kicker);
        SplitterLike(splitter).rely(kicker);

        dss.chainlog.setAddress(cfg.chainlogKey, kicker);
    }
}
