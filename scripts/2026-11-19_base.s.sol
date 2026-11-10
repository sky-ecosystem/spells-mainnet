// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.16;

import { DssExecLib } from "dss-exec-lib/DssExecLib.sol";
import { console } from "lib/dss-test/lib/forge-std/src/console.sol";
import { Script } from "lib/dss-test/lib/forge-std/src/Script.sol";

library IEnumerableIntegrations {
    struct Config {
        address facet;
        Wire[] wires;
    }
    struct Wire {
        bytes4 callSelector;
        bytes4 delegateSelector;
    }
}

interface BeaconLike {
    function getConfig(bytes32 integrationId) external view returns (IEnumerableIntegrations.Config memory);
    function setIntegration(bytes32 id, IEnumerableIntegrations.Config memory config) external;
}

interface BeamStateLike {
    function addCBeam(address cBeam) external;
    function addRateLimits(address rateLimits_) external;
    function setCBeamForRateLimits(address rateLimits_, address cBeam) external;
    function addController(address controller) external;
    function setCBeamForController(address controller, address cBeam) external;
    function setHop(address rateLimits_, uint256 value) external;
    function setMaxChange(address rateLimits_, uint256 value) external;
    function addInitRateLimits(bytes32 key, address rateLimits_, uint256 maxAmount, uint256 slope) external;
    function addInitControllerActions(bytes memory data, address controller) external returns (bytes32 key);
}

interface L2MulticallSpellLike {
    struct Call {
        address target;
        bytes   data;
    }
    function execute(Call[] calldata calls, uint256 deadline) external;
}

contract L2Spell20261119_base is Script {

    bytes32 internal constant INTEGRATION_ID         = "ERC4626_FACET";
    address internal constant BASE_PAU_BEACON        = 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41;
    address internal constant BASE_ERC4626_FACET     = 0xC6Fb54348feCdb2790Fa9130D1fc35d6E101C97D;
    address internal constant BASE_PAS_STATE         = 0x29840a8519013F483d94781b5C1671b552A109e1;
    address internal constant BASE_OSERO_CBEAM       = 0x42D1038017E466b413aa44Ae798E30FB80b2E180;
    address internal constant BASE_OSERO_RATE_LIMITS = 0xd9E629588c48722E4c1bfcfb17829FecAf73839f;
    address internal constant BASE_OSERO_CONTROLLER  = 0x96F18963c1B1Dd83bB4D14119cF2C4b94F86d6a9;

    function setUp() public {
        vm.createSelectFork("mainnet");
    }

    function run() external view {
        // Fetch required addresses
        address PAU_BEACON = DssExecLib.getChangelogAddress("PAU_BEACON");

        // Create empty multicall array
        L2MulticallSpellLike.Call[] memory calls = new L2MulticallSpellLike.Call[](6);

        // Populate with calldata
        IEnumerableIntegrations.Config memory config = BeaconLike(PAU_BEACON).getConfig(INTEGRATION_ID);
        config.facet = BASE_ERC4626_FACET;
        calls[0] = L2MulticallSpellLike.Call(BASE_PAU_BEACON, abi.encodeCall(BeaconLike.setIntegration, (INTEGRATION_ID, config)));
        console.log("Beacon.setIntegration calldata:");
        console.logBytes(calls[0].data);

        calls[1] = L2MulticallSpellLike.Call(BASE_PAS_STATE, abi.encodeCall(BeamStateLike.addCBeam, (BASE_OSERO_CBEAM)));
        console.log("Beacon.addCBeam calldata:");
        console.logBytes(calls[1].data);

        calls[2] = L2MulticallSpellLike.Call(BASE_PAS_STATE, abi.encodeCall(BeamStateLike.addRateLimits, (BASE_OSERO_RATE_LIMITS)));
        console.log("Beacon.addRateLimits calldata:");
        console.logBytes(calls[2].data);

        calls[3] = L2MulticallSpellLike.Call(BASE_PAS_STATE, abi.encodeCall(BeamStateLike.setCBeamForRateLimits, (BASE_OSERO_RATE_LIMITS, BASE_OSERO_CBEAM)));
        console.log("Beacon.setCBeamForRateLimits calldata:");
        console.logBytes(calls[3].data);

        calls[4] = L2MulticallSpellLike.Call(BASE_PAS_STATE, abi.encodeCall(BeamStateLike.addController, (BASE_OSERO_CONTROLLER)));
        console.log("Beacon.addController calldata:");
        console.logBytes(calls[4].data);

        calls[5] = L2MulticallSpellLike.Call(BASE_PAS_STATE, abi.encodeCall(BeamStateLike.setCBeamForController, (BASE_OSERO_CONTROLLER, BASE_OSERO_CBEAM)));
        console.log("Beacon.setCBeamForController calldata:");
        console.logBytes(calls[5].data);

        // Generate final calldata to pass to BASE_GOV_RELAY.relay
        bytes memory callData = abi.encodeCall(L2MulticallSpellLike.execute, (calls, block.timestamp + 7 days));
        console.log("Final calldata to relay:");
        console.logBytes(callData);
    }

}
