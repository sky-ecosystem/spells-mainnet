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

contract AvalancheAddresses {

    mapping (bytes32 => address) public addr;

    constructor() {
        addr["L2_AVALANCHE_LZ_GOV_RECEIVER"]    = 0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec;
        addr["L2_AVALANCHE_LZ_GOV_RELAY"]       = 0xe928885BCe799Ed933651715608155F01abA23cA;
        addr["L2_AVALANCHE_USDS"]               = 0x86Ff09db814ac346a7C6FE2Cd648F27706D1D470;
        addr["L2_AVALANCHE_USDS_OFT"]           = 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619;
        addr["L2_AVALANCHE_SUSDS"]              = 0xb94D9613C7aAB11E548a327154Cc80eCa911B5c1;
        addr["L2_AVALANCHE_SUSDS_OFT"]          = 0x7297D4811f088FC26bC5475681405B99b41E1FF9;
        addr["L2_AVALANCHE_LZ_ENDPOINT"]        = 0x1a44076050125825900e736c501f859c50fE728c;
        addr["L2_AVALANCHE_LZ_SEND_302"]        = 0x197D1333DEA5Fe0D6600E9b396c7f1B1cFCc558a;
        addr["L2_AVALANCHE_LZ_RECV_302"]        = 0xbf3521d309642FA9B1c91A08609505BA09752c61;
        addr["L2_AVALANCHE_LZ_EXECUTOR"]        = 0x90E595783E43eb89fF07f63d27B8430e6B44bD9c;
        addr["L2_AVALANCHE_OFT_PAUSER"]         = 0x4deb1B5372dd3271691A9E80bCBfd98F5aa27f30;
    }
}
