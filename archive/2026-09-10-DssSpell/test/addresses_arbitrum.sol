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

contract ArbitrumAddresses {

    mapping (bytes32 => address) public addr;
    constructor() {
        addr["L2_USDS"]                         = 0x6491c05A82219b8D1479057361ff1654749b876b;
        addr["L2_SUSDS"]                        = 0xdDb46999F8891663a8F2828d25298f70416d7610;
        addr["L2_TOKEN_BRIDGE"]                 = 0x13F7F24CA959359a4D710D32c715D4bce273C793;
        addr["L2_TOKEN_BRIDGE_IMP"]             = 0xD404eD36D6976BdCad8ABbcCC9F09ef07e33A9A8;
        addr["L2_TOKEN_BRIDGE_SPELL"]           = 0x3D4357c3944F7A5b6a0B5b67B36588BA45D3f49D;
        addr["L2_ROUTER"]                       = 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933;
        addr["L2_GOV_RELAY"]                    = 0x10E6593CDda8c58a1d0f14C5164B376352a55f2F;
    }
}
