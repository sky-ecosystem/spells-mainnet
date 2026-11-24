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

contract BaseAddresses {

    mapping (bytes32 => address) public addr;

    constructor() {
        addr["L2_BASE_TOKEN_BRIDGE"]      = 0xee44cdb68D618d58F75d9fe0818B640BD7B8A7B7;
        addr["L2_GOV_RELAY"]              = 0xdD0BCc201C9E47c6F6eE68E4dB05b652Bb6aC255;
        addr["L2_SPELL"]                  = 0x6f29C3A29A3F056A71FB0714551C8D3547268D62;
        addr["L2_USDC"]                   = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        addr["L2_USDS"]                   = 0x820C137fa70C8691f0e44Dc420a5e53c168921Dc;
        addr["L2_SUSDS"]                  = 0x5875eEE11Cf8398102FdAd704C9E96607675467a;
        addr["L2_BASE_TOKEN_BRIDGE_IMP"]  = 0x289A37BE5D6CCeF7A8f2b90535B3BB6bD3905f72;
        addr["L2_MESSENGER"]              = 0x4200000000000000000000000000000000000007;
        addr["L2_PAS_STATE"]              = 0x29840a8519013F483d94781b5C1671b552A109e1;
        addr["L2_PAS_CONFIGURATOR"]       = 0x458Acd38fD749F6325039e63e8Bc496dBc286D11;
        addr["L2_PAS_TIMELOCK"]           = 0x2ACADc011b4fc13072F92231D1216c16deac5188;
        addr["L2_PAU_BEACON"]             = 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41;
        addr["L2_ERC4626_FACET"]          = 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D;
        addr["L2_MULTICALL_SPELL"]        = 0x682048513247076Fb5dB4762121BdB136182e4A9;
        addr["BASE_OSERO_RATE_LIMITS"]    = 0xd9E629588c48722E4c1bfcfb17829FecAf73839f;
        addr["BASE_OSERO_CONTROLLER"]     = 0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9;
        addr["BASE_OSERO_USDC_VAULT"]     = 0x8c1e205C408b90A0dDDbD53594049a379557c651;
    }
}
