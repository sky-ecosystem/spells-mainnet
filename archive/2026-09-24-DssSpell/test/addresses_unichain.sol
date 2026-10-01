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

contract UnichainAddresses {

    mapping (bytes32 => address) public addr;

    constructor() {
        addr["L2_UNICHAIN_GOV_RELAY"]           = 0x3510a7F16F549EcD0Ef018DE0B3c2ad7c742990f;
        addr["L2_UNICHAIN_TOKEN_BRIDGE"]        = 0xa13152006D0216Fe4627a0D3B006087A6a55D752;
        addr["L2_UNICHAIN_TOKEN_BRIDGE_IMP"]    = 0xd78292C12707CF28E8EB7bf06fA774D1044C2dF5;
        addr["L2_UNICHAIN_USDS"]                = 0x7E10036Acc4B56d4dFCa3b77810356CE52313F9C;
        addr["L2_UNICHAIN_SUSDS"]               = 0xA06b10Db9F390990364A3984C04FaDf1c13691b5;
        addr["L2_UNICHAIN_SPELL"]               = 0x32760698c87834c02ED9AFF2d4FC3e16c029B936;
        addr["L2_UNICHAIN_MESSENGER"]           = 0x4200000000000000000000000000000000000007;
    }
}
