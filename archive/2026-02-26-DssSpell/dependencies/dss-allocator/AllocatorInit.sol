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

import { ScriptTools } from "dss-test/ScriptTools.sol";
import { DssInstance } from "dss-test/MCD.sol";
import { AllocatorSharedInstance, AllocatorIlkInstance } from "./AllocatorInstances.sol";

interface IlkRegistryLike {
    function put(
        bytes32 _ilk,
        address _join,
        address _gem,
        uint256 _dec,
        uint256 _class,
        address _pip,
        address _xlip,
        string calldata _name,
        string calldata _symbol
    ) external;
}

interface RolesLike {
    function setIlkAdmin(bytes32, address) external;
}

interface RegistryLike {
    function file(bytes32, bytes32, address) external;
}

interface VaultLike {
    function ilk() external view returns (bytes32);
    function roles() external view returns (address);
    function buffer() external view returns (address);
    function vat() external view returns (address);
    function usds() external view returns (address);
    function file(bytes32, address) external;
}

interface BufferLike {
    function approve(address, address, uint256) external;
}

interface AutoLineLike {
    function setIlk(bytes32, uint256, uint256, uint256) external;
}

struct AllocatorIlkConfig {
    bytes32 ilk;
    uint256 duty;
    uint256 gap;
    uint256 maxLine;
    uint256 ttl;
    address allocatorProxy;
    address ilkRegistry;
}

function bytes32ToStr(bytes32 _bytes32) pure returns (string memory) {
    uint256 len;
    while(len < 32 && _bytes32[len] != 0) len++;
    bytes memory bytesArray = new bytes(len);
    for (uint256 i; i < len; i++) {
        bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
}

library AllocatorInit {
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    uint256 constant RATES_ONE_HUNDRED_PCT = 1000000021979553151239153027;

    function initShared(
        DssInstance memory dss,
        AllocatorSharedInstance memory sharedInstance
    ) internal {
        dss.chainlog.setAddress("ALLOCATOR_ROLES",    sharedInstance.roles);
        dss.chainlog.setAddress("ALLOCATOR_REGISTRY", sharedInstance.registry);
    }

    // Please note this should be executed by the pause proxy
    function initIlk(
        DssInstance memory dss,
        AllocatorSharedInstance memory sharedInstance,
        AllocatorIlkInstance memory ilkInstance,
        AllocatorIlkConfig memory cfg
    ) internal {
        bytes32 ilk = cfg.ilk;

        // Sanity checks
        require(VaultLike(ilkInstance.vault).ilk()    == ilk,                  "AllocatorInit/vault-ilk-mismatch");
        require(VaultLike(ilkInstance.vault).roles()  == sharedInstance.roles, "AllocatorInit/vault-roles-mismatch");
        require(VaultLike(ilkInstance.vault).buffer() == ilkInstance.buffer,   "AllocatorInit/vault-buffer-mismatch");
        require(VaultLike(ilkInstance.vault).vat()    == address(dss.vat),     "AllocatorInit/vault-vat-mismatch");
        // Once usdsJoin is in the chainlog and adapted to dss-test should also check against it

        // Onboard the ilk
        dss.vat.init(ilk);
        dss.jug.init(ilk);

        require((cfg.duty >= RAY) && (cfg.duty <= RATES_ONE_HUNDRED_PCT), "AllocatorInit/ilk-duty-out-of-bounds");
        dss.jug.file(ilk, "duty", cfg.duty);

        dss.vat.file(ilk, "line", cfg.gap);
        dss.vat.file("Line", dss.vat.Line() + cfg.gap);
        AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).setIlk(ilk, cfg.maxLine, cfg.gap, cfg.ttl);

        dss.spotter.file(ilk, "pip", sharedInstance.oracle);
        dss.spotter.file(ilk, "mat", RAY);
        dss.spotter.poke(ilk);

        // Add buffer to registry
        RegistryLike(sharedInstance.registry).file(ilk, "buffer", ilkInstance.buffer);

        // Initiate the allocator vault
        dss.vat.slip(ilk, ilkInstance.vault, int256(10**12 * WAD));
        dss.vat.grab(ilk, ilkInstance.vault, ilkInstance.vault, address(0), int256(10**12 * WAD), 0);

        VaultLike(ilkInstance.vault).file("jug", address(dss.jug));

        // Allow vault to pull funds from the buffer
        BufferLike(ilkInstance.buffer).approve(VaultLike(ilkInstance.vault).usds(), ilkInstance.vault, type(uint256).max);

        // Set the allocator proxy as the ilk admin instead of the Pause Proxy
        RolesLike(sharedInstance.roles).setIlkAdmin(ilk, cfg.allocatorProxy);

        // Move ownership of the ilk contracts to the allocator proxy
        ScriptTools.switchOwner(ilkInstance.vault,  ilkInstance.owner, cfg.allocatorProxy);
        ScriptTools.switchOwner(ilkInstance.buffer, ilkInstance.owner, cfg.allocatorProxy);

        // Add allocator-specific contracts to changelog
        string memory ilkString = ScriptTools.ilkToChainlogFormat(ilk);
        dss.chainlog.setAddress(ScriptTools.stringToBytes32(string(abi.encodePacked(ilkString, "_VAULT"))),  ilkInstance.vault);
        dss.chainlog.setAddress(ScriptTools.stringToBytes32(string(abi.encodePacked(ilkString, "_BUFFER"))), ilkInstance.buffer);
        dss.chainlog.setAddress(ScriptTools.stringToBytes32(string(abi.encodePacked("PIP_", ilkString))), sharedInstance.oracle);

        // Add to ilk registry
        IlkRegistryLike(cfg.ilkRegistry).put({
            _ilk    : ilk,
            _join   : address(0),
            _gem    : address(0),
            _dec    : 0,
            _class  : 5, // RWAs are class 3, D3Ms and Teleport are class 4
            _pip    : sharedInstance.oracle,
            _xlip   : address(0),
            _name   : bytes32ToStr(ilk),
            _symbol : bytes32ToStr(ilk)
        });
    }
}
