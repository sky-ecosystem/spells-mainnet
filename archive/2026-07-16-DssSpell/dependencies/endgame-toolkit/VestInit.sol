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

struct VestCreateParams {
    address usr;
    uint256 tot;
    uint256 bgn;
    uint256 tau;
    uint256 eta;
}

/// @dev Handles vesting stream creation. Assumes `DssVest` parameters are initialized somewhere else.
library VestInit {
    function create(address vest, VestCreateParams memory p) internal returns (uint256 vestId) {
        vestId = DssVestLike(vest).create(
            p.usr,
            p.tot,
            p.bgn,
            p.tau,
            p.eta,
            address(0) // mgr
        );

        DssVestLike(vest).restrict(vestId);
    }
}

interface DssVestLike {
    function create(
        address _usr,
        uint256 _tot,
        uint256 _bgn,
        uint256 _tau,
        uint256 _eta,
        address _mgr
    ) external returns (uint256 id);

    function restrict(uint256 _id) external;
}
