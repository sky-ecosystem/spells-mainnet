// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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

interface ChainLogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
    function setAddress(bytes32 _key, address _addr) external;
}

interface StarGuardLike {
    function file(bytes32 what, uint256 data) external;
    function subProxy() external view returns (address subProxy);
    function spellData() external view returns (address addr, bytes32 tag, uint256 deadline);
    function wards(address usr) external view returns (uint256 allowed);
}

interface SubProxyLike {
    function rely(address usr) external;
}

struct StarGuardConfig {
    address subProxy;
    bytes32 subProxyKey;
    address starGuard;
    bytes32 starGuardKey;
    uint256 maxDelay;
}

library StarGuardInit {
    function init(
        address chainlog,
        StarGuardConfig memory cfg
    ) internal {
        address pauseProxy = ChainLogLike(chainlog).getAddress("MCD_PAUSE_PROXY");

        require(StarGuardLike(cfg.starGuard).wards(pauseProxy) == 1, "StarGuardInit/pauseProxy-not-authorized");
        require(StarGuardLike(cfg.starGuard).subProxy() == address(cfg.subProxy), "StarGuardInit/subProxy-does-not-match");
        require(cfg.maxDelay > 0, "StarGuardInit/invalid-maxDelay");
        (address addr,,) = StarGuardLike(cfg.starGuard).spellData();
        require(addr == address(0), "StarGuardInit/unexpected-plotted-spell");

        StarGuardLike(cfg.starGuard).file("maxDelay", cfg.maxDelay);
        SubProxyLike(cfg.subProxy).rely(cfg.starGuard);

        if (cfg.subProxyKey != bytes32(0)) {
            ChainLogLike(chainlog).setAddress(cfg.subProxyKey, cfg.subProxy);
        }
        ChainLogLike(chainlog).setAddress(cfg.starGuardKey, cfg.starGuard);
    }
}
