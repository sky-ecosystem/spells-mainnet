// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
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
import { PASInstance } from "./PASInstance.sol";

interface BeamStateLike {
    function rely(address) external;
    function setUserRole(address, uint8, bool) external;
    function setRoleAction(uint8, bytes4, bool) external;
    function stop() external;
    function start() external;
    function setHop(address, uint256) external;
    function setMaxChange(address, uint256) external;
    function addRateLimits(address) external;
    function delRateLimits(address) external;
    function addController(address) external;
    function delController(address) external;
    function addCBeam(address) external;
    function delCBeam(address) external;
    function setCBeamForRateLimits(address, address) external;
    function unsetCBeamForRateLimits(address, address) external;
    function setCBeamForController(address, address) external;
    function unsetCBeamForController(address, address) external;
    function addInitRateLimits(bytes32, address, uint256, uint256) external;
    function delInitRateLimits(bytes32, address) external;
    function addInitControllerActions(bytes calldata data, address) external;
    function delInitControllerActions(bytes32, address) external;
}

interface ConfiguratorLike {
    function beamState() external view returns (address);
}

interface TimelockLike {
    function getMinDelay() external view returns (uint256);
    function PROPOSER_ROLE() external view returns (bytes32);
    function CANCELLER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function grantRole(bytes32, address) external;
    function revokeRole(bytes32, address) external;
    function pause() external;
}

interface PASMomLike {
    function beamState() external view returns (address);
    function timelock() external view returns (address);
    function setAuthority(address) external;
}

struct InitCBeamConfig {
    address   cBeam;
    address[] rateLimits;
    address[] controllers;
}

struct InitRateLimitConfig {
    bytes32 key;
    address rateLimits;
    uint256 maxAmount;
    uint256 slope;
}

struct InitControllerActionConfig {
    bytes   data;
    address controller;
}

library PASInit {

    // It is noted that delayed and immediate operations order is non deterministic.
    // The relevant operators of each role are assumed to communicate and track timelock and configurator executions.
    enum Role {
        _UNSET,   // 0 (unused)
        DELAYED,  // 1
        IMMEDIATE // 2
    }

    function init(
        PASInstance memory pasInstance,
        uint256            minDelay,
        address            coreCouncil,
        address[]   memory cancellers,
        address[]   memory pausers
    ) internal {
        BeamStateLike    beamState    = BeamStateLike(pasInstance.beamState);
        ConfiguratorLike configurator = ConfiguratorLike(pasInstance.configurator);
        TimelockLike     timelock     = TimelockLike(pasInstance.timelock);

        // --- Sanity checks ---

        require(configurator.beamState() == address(beamState), "PASInit/configurator-beamState-mismatch");
        require(timelock.getMinDelay()   == minDelay,           "PASInit/timelock-minDelay-mismatch");

        // --- Configure BeamState ---

        // Define Beam actions that are accessed through timelock (DELAYED) and directly (IMMEDIATE)
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.start.selector,                    true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.setHop.selector,                   true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.setMaxChange.selector,             true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.addRateLimits.selector,            true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.addController.selector,            true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.addCBeam.selector,                 true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.addInitRateLimits.selector,        true);
        beamState.setRoleAction(uint8(Role.DELAYED),   BeamStateLike.addInitControllerActions.selector, true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.stop.selector,                     true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.delRateLimits.selector,            true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.delController.selector,            true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.delCBeam.selector,                 true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.setCBeamForRateLimits.selector,    true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.unsetCBeamForRateLimits.selector,  true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.setCBeamForController.selector,    true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.unsetCBeamForController.selector,  true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.delInitRateLimits.selector,        true);
        beamState.setRoleAction(uint8(Role.IMMEDIATE), BeamStateLike.delInitControllerActions.selector, true);

        // Set timelock as the user with DELAYED role and coreCouncil with IMMEDIATE role
        beamState.setUserRole(address(timelock), uint8(Role.DELAYED),   true);
        beamState.setUserRole(coreCouncil,       uint8(Role.IMMEDIATE), true);

        // --- Configure Timelock ---

        // Grant the coreCouncil as the proposer in the timelock directly
        // Grant cancellers and pausers in timelock with their respective roles
        timelock.grantRole(timelock.PROPOSER_ROLE(),  coreCouncil);
        timelock.grantRole(timelock.CANCELLER_ROLE(), coreCouncil);
        for (uint256 i = 0; i < cancellers.length; ++i) {
            timelock.grantRole(timelock.CANCELLER_ROLE(), cancellers[i]);
        }
        for (uint256 i = 0; i < pausers.length; ++i) {
            timelock.grantRole(timelock.PAUSER_ROLE(), pausers[i]);
        }
    }

    // Call after `init` for starting with spell-only configurations of `DELAYED` actions
    // The admin is assumed not to be listed in the pausers array, so we do not mistakenly revoke its role
    function pauseTimelock(
        address timelock_,
        address admin
    ) internal {
        TimelockLike timelock = TimelockLike(timelock_);

        timelock.grantRole(timelock.PAUSER_ROLE(), admin);
        timelock.pause();
        timelock.revokeRole(timelock.PAUSER_ROLE(), admin);
    }

    function initExtras(
        PASInstance memory pasInstance,
        uint256 hop,
        uint256 maxChange,
        address[] memory rateLimits,
        address[] memory controllers,
        InitCBeamConfig[] memory cBeamConfigs
    ) internal {
        require(hop > 0, "PASInit/hop-is-zero");

        BeamStateLike beamState = BeamStateLike(pasInstance.beamState);

        beamState.setHop(address(0), hop);
        beamState.setMaxChange(address(0), maxChange);
        for(uint256 i; i < rateLimits.length; i++) {
            beamState.addRateLimits(rateLimits[i]);
        }
        for(uint256 i; i < controllers.length; i++) {
            beamState.addController(controllers[i]);
        }
        for(uint256 i; i < cBeamConfigs.length; i++) {
            InitCBeamConfig memory c = cBeamConfigs[i];
            beamState.addCBeam(c.cBeam);
            for(uint256 j; j < c.rateLimits.length; j++) {
                beamState.setCBeamForRateLimits(c.rateLimits[j], c.cBeam);
            }
            for(uint256 j; j < c.controllers.length; j++) {
                beamState.setCBeamForController(c.controllers[j], c.cBeam);
            }
        }
    }

    function initLimitsAndControllerData(
        PASInstance                  memory pasInstance,
        InitRateLimitConfig[]        memory rateLimitConfigs,
        InitControllerActionConfig[] memory controllerActionConfigs
    ) internal {
        BeamStateLike beamState = BeamStateLike(pasInstance.beamState);

        for (uint256 i; i < rateLimitConfigs.length; i++) {
            beamState.addInitRateLimits(
                rateLimitConfigs[i].key,
                rateLimitConfigs[i].rateLimits,
                rateLimitConfigs[i].maxAmount,
                rateLimitConfigs[i].slope
            );
        }
        for (uint256 i; i < controllerActionConfigs.length; i++) {
            beamState.addInitControllerActions(
                controllerActionConfigs[i].data,
                controllerActionConfigs[i].controller
            );
        }
    }

    function addCoreToChainlog(
        DssInstance memory dss,
        PASInstance memory pasInstance,
        bytes32 stateKey,
        bytes32 configuratorKey,
        bytes32 timelockKey
    ) internal {
        dss.chainlog.setAddress(stateKey,        pasInstance.beamState);
        dss.chainlog.setAddress(configuratorKey, pasInstance.configurator);
        dss.chainlog.setAddress(timelockKey,     pasInstance.timelock);
    }

    function initMom(
        DssInstance memory dss,
        PASInstance memory pasInstance,
        address mom_,
        bytes32 key
    ) internal {
        BeamStateLike beamState = BeamStateLike(pasInstance.beamState);
        TimelockLike  timelock  = TimelockLike(pasInstance.timelock);
        PASMomLike    mom       = PASMomLike(mom_);

        // --- Sanity checks ---

        require(mom.beamState() == address(beamState), "PASInit/mom-beamState-mismatch");
        require(mom.timelock()  == address(timelock),  "PASInit/mom-timelock-mismatch");

        // --- Set permissions ---

        // Rely Mom on BeamState to call stop()
        beamState.rely(address(mom));
        // Give Mom the PAUSER_ROLE to call pause() on Timelock
        timelock.grantRole(timelock.PAUSER_ROLE(), address(mom));
        // Set Mom's authority to MCD_ADM
        mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        // --- Chainlog ---

        dss.chainlog.setAddress(key, address(mom));
    }
}
