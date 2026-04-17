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

contract PlasmaAddresses {

    mapping (bytes32 => address) public addr;

    constructor() {
        addr["L2_PLASMA_LZ_GOV_RECEIVER"]    = 0x2172120c774510F9b0deDb5378a17A4b7E822C35;
        addr["L2_PLASMA_LZ_GOV_RELAY"]       = 0x5CE28f2dD353945db9AB3273A2a1dD1AB632e24b;
        addr["L2_PLASMA_USDS"]               = 0x68d607c551Fb3c01322Da7a064d60bEA15A8E2bb;
        addr["L2_PLASMA_USDS_OFT"]           = 0x8544b2E758E56B8B45909435bE6EA3E8e8500Cf1;
        addr["L2_PLASMA_SUSDS"]              = 0xAB7836F0F7A3ad0afFDAE83aEbeE414532BE56a8;
        addr["L2_PLASMA_SUSDS_OFT"]          = 0xb6e64c49C335E507DBa8Dd7b05bC6c9FbAdCE601;
        addr["L2_PLASMA_LZ_ENDPOINT"]        = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        addr["L2_PLASMA_LZ_SEND_302"]        = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7;
        addr["L2_PLASMA_LZ_RECV_302"]        = 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043;
        addr["L2_PLASMA_LZ_EXECUTOR"]        = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;
    }
}
