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

contract OptimismAddresses {

    mapping (bytes32 => address) public addr;

    constructor() {
        addr["L2_OPTIMISM_GOV_RELAY"]           = 0x10E6593CDda8c58a1d0f14C5164B376352a55f2F;
        addr["L2_OPTIMISM_TOKEN_BRIDGE"]        = 0x8F41DBF6b8498561Ce1d73AF16CD9C0d8eE20ba6;
        addr["L2_OPTIMISM_TOKEN_BRIDGE_IMP"]    = 0xc2702C859016db756149716cc4d2B7D7A436CF04;
        addr["L2_OPTIMISM_USDS"]                = 0x4F13a96EC5C4Cf34e442b46Bbd98a0791F20edC3;
        addr["L2_OPTIMISM_SUSDS"]               = 0xb5B2dc7fd34C249F4be7fB1fCea07950784229e0;
        addr["L2_OPTIMISM_SPELL"]               = 0x99892216eD34e8FD924A1dBC758ceE61a9109409;
        addr["L2_OPTIMISM_MESSENGER"]           = 0x4200000000000000000000000000000000000007;
    }
}
