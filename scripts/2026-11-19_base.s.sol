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

interface L2GovRelayLike {
    function l1GovernanceRelay() external view returns (address);
    function messenger() external view returns (address);
    function relay(address target, bytes calldata targetData) external;
}

interface L2MessengerLike {
    function xDomainMessageSender() external view returns (address);
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
    address internal constant BASE_L2_GOV_RELAY      = 0xdD0BCc201C9E47c6F6eE68E4dB05b652Bb6aC255;
    address internal constant BASE_L2MULTICALLSPELL  = 0x682048513247076Fb5dB4762121BdB136182e4A9;

    uint256 internal mainnetFork;
    uint256 internal baseFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet");
        baseFork    = vm.createFork(getChain("base").rpcUrl);
    }

    function _generateCalldata() internal returns (bytes memory callData) {
        vm.selectFork(mainnetFork);

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
        callData = abi.encodeCall(L2MulticallSpellLike.execute, (calls, block.timestamp + 7 days));
        console.log("Final calldata to relay:");
        console.logBytes(callData);
    }

    function _estimateGasOnBase(bytes memory callData) internal {
        vm.selectFork(baseFork);

        require(BASE_L2MULTICALLSPELL.code.length > 0, "L2MulticallSpell/not-deployed-on-base");

        address l1GovRelay = L2GovRelayLike(BASE_L2_GOV_RELAY).l1GovernanceRelay();
        address messenger  = L2GovRelayLike(BASE_L2_GOV_RELAY).messenger();

        // Emulate the L1 -> L2 message since L2GovRelay only accepts calls from the messenger
        vm.mockCall(messenger, abi.encodeCall(L2MessengerLike.xDomainMessageSender, ()), abi.encode(l1GovRelay));

        bytes memory relayData = abi.encodeCall(L2GovRelayLike.relay, (BASE_L2MULTICALLSPELL, callData));

        vm.prank(messenger);
        uint256 gasBefore = gasleft();
        (bool success, bytes memory ret) = BASE_L2_GOV_RELAY.call(relayData);
        uint256 gasUsed = gasBefore - gasleft();

        vm.clearMockedCalls();

        if (!success) {
            console.log("L2GovRelay.relay reverted on Base:");
            console.logBytes(ret);
            revert("L2MulticallSpell/execution-failed-on-base");
        }

        console.log("Suggested _minGasLimit (minimum + 30%):");
        console.log(gasUsed * 13 / 10);
    }

    function run() external {
        _estimateGasOnBase(_generateCalldata());
    }

}
