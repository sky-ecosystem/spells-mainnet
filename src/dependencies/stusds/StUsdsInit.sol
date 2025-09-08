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
import { StUsdsInstance } from "./StUsdsInstance.sol";

interface StUsdsLike {
    function version() external view returns (string memory);
    function getImplementation() external view returns (address);
    function usdsJoin() external view returns (address);
    function jug() external view returns (address);
    function clip() external view returns (address);
    function vow() external view returns (address);
    function ilk() external view returns (bytes32);
    function file(bytes32, uint256) external;
    function drip() external returns (uint256);
    function rely(address) external;
}

interface AutoLineLike {
    function remIlk(bytes32) external;
}

interface RateSetterLike {
    function jug() external view returns (address);
    function stusds() external view returns (address);
    function conv() external view returns (address);
    function file(bytes32, uint256) external;
    function file(bytes32, bytes32, uint256) external;
    function kiss(address) external;
    function rely(address) external;
}

interface SPBEAMLike {
    function conv() external view returns (address);
}

interface StUsdsMomLike {
    function stusds() external view returns (address);
    function setAuthority(address) external;
}

struct StUsdsConfig {
    address clip;
    uint256 str;
    uint256 cap;
    uint256 line;

    // RateSetter configuration
    uint256   tau;
    uint256   maxLine;
    uint256   maxCap;
    uint256   minStrBps;
    uint256   maxStrBps;
    uint256   stepStrBps;
    uint256   minDutyBps;
    uint256   maxDutyBps;
    uint256   stepDutyBps;
    address[] buds;
}

library StUsdsInit {

    uint256 constant internal RAY                   = 10**27;
    uint256 constant internal RATES_ONE_HUNDRED_PCT = 1000000021979553151239153027;

    function init(
        DssInstance    memory dss,
        StUsdsInstance memory instance,
        StUsdsConfig   memory cfg
    ) internal {
        require(keccak256(abi.encodePacked(StUsdsLike(instance.stUsds).version())) == keccak256(abi.encodePacked("1")), "StUsdsInit/version-does-not-match");
        require(StUsdsLike(instance.stUsds).getImplementation() == instance.stUsdsImp, "StUsdsInit/imp-does-not-match");

        require(StUsdsLike(instance.stUsds).usdsJoin() == dss.chainlog.getAddress("USDS_JOIN"), "StUsdsInit/usdsJoin-does-not-match");
        require(StUsdsLike(instance.stUsds).jug()      == address(dss.jug),                     "StUsdsInit/jug-does-not-match");
        require(StUsdsLike(instance.stUsds).clip()     == cfg.clip,                             "StUsdsInit/clip-does-not-match");
        require(StUsdsLike(instance.stUsds).vow()      == address(dss.vow),                     "StUsdsInit/vow-does-not-match");

        require(cfg.str >= RAY && cfg.str <= RATES_ONE_HUNDRED_PCT, "StUsdsInit/str-out-of-boundaries");

        require(RateSetterLike(instance.rateSetter).stusds() == instance.stUsds, "StUsdsInit/stusds-does-not-match");
        require(RateSetterLike(instance.rateSetter).conv() == SPBEAMLike(dss.chainlog.getAddress("MCD_SPBEAM")).conv(), "StUsdsInit/conv-does-not-match");

        require(StUsdsMomLike(instance.mom).stusds() == instance.stUsds, "StUsdsInit/stusds-does-not-match");

        dss.vat.rely(instance.stUsds);

        bytes32 ilk = StUsdsLike(instance.stUsds).ilk();

        AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).remIlk(ilk);

        StUsdsLike(instance.stUsds).drip();
        StUsdsLike(instance.stUsds).file("str",  cfg.str);
        StUsdsLike(instance.stUsds).file("cap",  cfg.cap);
        StUsdsLike(instance.stUsds).file("line", cfg.line);

        // RateSetter Configuration
        dss.jug.rely(instance.rateSetter);
        StUsdsLike(instance.stUsds).rely(instance.rateSetter);

        RateSetterLike(instance.rateSetter).file("tau",     cfg.tau);
        RateSetterLike(instance.rateSetter).file("maxLine", cfg.maxLine);
        RateSetterLike(instance.rateSetter).file("maxCap",  cfg.maxCap);

        // Note: we configure max first on purpose to initially pass the max > min validation
        RateSetterLike(instance.rateSetter).file("STR", "max",  cfg.maxStrBps);
        RateSetterLike(instance.rateSetter).file("STR", "min",  cfg.minStrBps);
        RateSetterLike(instance.rateSetter).file("STR", "step", cfg.stepStrBps);

        RateSetterLike(instance.rateSetter).file(ilk, "max",  cfg.maxDutyBps);
        RateSetterLike(instance.rateSetter).file(ilk, "min",  cfg.minDutyBps);
        RateSetterLike(instance.rateSetter).file(ilk, "step", cfg.stepDutyBps);

        for (uint256 i; i < cfg.buds.length; i ++) {
            RateSetterLike(instance.rateSetter).kiss(cfg.buds[i]);
        }

        // Mom Configuration
        StUsdsLike(instance.stUsds).rely(instance.mom);
        RateSetterLike(instance.rateSetter).rely(instance.mom);
        StUsdsMomLike(instance.mom).setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        dss.chainlog.setAddress("STUSDS",             instance.stUsds);
        dss.chainlog.setAddress("STUSDS_IMP",         instance.stUsdsImp);
        dss.chainlog.setAddress("STUSDS_RATE_SETTER", instance.rateSetter);
        dss.chainlog.setAddress("STUSDS_MOM",         instance.mom);
    }
}
