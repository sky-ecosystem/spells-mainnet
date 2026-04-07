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

import "dss-exec-lib/DssExec.sol";
import "dss-exec-lib/DssAction.sol";

struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

struct ExecutorConfig {
    uint32 maxMessageSize;
    address executor;
}

struct RateLimitConfig {
    uint32 eid;
    uint48 window;
    uint256 limit;
}

interface GovernanceOAppSenderLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
    function setPeer(uint32 _eid, bytes32 _peer) external;
}

interface EndpointV2Like {
    struct SetConfigParam {
        uint32 eid;
        uint32 configType;
        bytes config;
    }
    function setConfig(address _oapp, address _lib, SetConfigParam[] memory _params) external;
    function setReceiveLibrary(address _oapp, uint32 _eid, address _newLib, uint256 _gracePeriod) external;
    function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external;
}

interface SkyOFTAdapterLike {
    struct EnforcedOptionParam {
        uint32 eid;
        uint16 msgType;
        bytes options;
    }
    function setPeer(uint32 _eid, bytes32 _peer) external;
    function setEnforcedOptions(EnforcedOptionParam[] memory _enforcedOptions) external;
    function setPauser(address _pauser, bool _canPause) external;
    function setRateLimits(RateLimitConfig[] memory _rateLimitConfigsInbound, RateLimitConfig[] memory _rateLimitConfigsOutbound) external;
}

interface StarGuardLike {
    function plot(address _spell, bytes32 _hash) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-04-09 MakerDAO Executive Spell | Hash: TODO";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Rates ----------
    // Many of the settings that change weekly rely on the rate accumulator
    // described at https://docs.makerdao.com/smart-contract-modules/rates-module
    // To check this yourself, use the following rate calculation (example 8%):
    //
    // $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'
    //
    // A table of rates can be found at
    //    https://ipfs.io/ipfs/QmVp4mhhbwWGTfbh2BzwQB9eiBrQBKiqcPRZCaAxNUaar6
    //
    // uint256 internal constant X_PCT_RATE = ;

    // ---------- Math ----------
    uint256 internal constant WAD     = 10 ** 18;

    // ---------- Contracts ----------
    address internal immutable CHAINLOG         = DssExecLib.LOG;
    address internal immutable LZ_GOV_SENDER    = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable LZ_GOV_RELAY     = DssExecLib.getChangelogAddress("LZ_GOV_RELAY");
    address internal immutable USDS_OFT         = DssExecLib.getChangelogAddress("USDS_OFT");
    address internal immutable SPARK_STARGUARD  = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD  = DssExecLib.getChangelogAddress("GROVE_STARGUARD");

    // ---------- LayerZero ----------
    uint32  internal constant AVAX_EID              = 30106;
    address internal constant ETH_LZ_ENDPOINT       = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant ETH_LZ_SEND_302       = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
    address internal constant ETH_LZ_RECV_302       = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
    address internal constant ETH_LZ_EXECUTOR       = 0x173272739Bd7Aa6e4e214714048a9fE699453059;
    bytes32 internal constant AVAX_GOV_RECEIVER     = bytes32(uint256(uint160(0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec)));
    bytes32 internal constant AVAX_L2_GOV_RELAY     = bytes32(uint256(uint160(0xe928885BCe799Ed933651715608155F01abA23cA)));
    bytes32 internal constant AVAX_USDS_OFT         = bytes32(uint256(uint160(0x4fec40719fD9a8AE3F8E20531669DEC5962D2619)));
    address internal constant ETH_SUSDS_OFT         = 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1;
    bytes32 internal constant AVAX_SUSDS_OFT        = bytes32(uint256(uint160(0x7297D4811f088FC26bC5475681405B99b41E1FF9)));

    // ---------- Spark ----------
    address internal constant SPARK_SPELL      = 0xFa5fc020311fCC1A467FEC5886640c7dD746deAa;
    bytes32 internal constant SPARK_SPELL_HASH = 0x2572a97846f7a6f9f159a9a69c2707cfa4186c061de2a0ec59e7a0d46473c74c;

    // ---------- Grove ----------
    address internal constant GROVE_SPELL      = 0x679eD4739c71300f7d78102AE5eE17EF8b8b2162;
    bytes32 internal constant GROVE_SPELL_HASH = 0x4fa1f743b3d6d2855390724459129186dd684e1c07d59f88925f0059ba1e6c84;

    // Note: OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0) constants (0003010011010000000000000000000000000001fbd0)
    uint16 internal constant LZ_OPTIONS_TYPE_3             = 3;
    uint8  internal constant LZ_EXECUTOR_WORKER_ID         = 1;
    uint8  internal constant LZ_OPTION_TYPE_LZRECEIVE      = 1;
    uint128 internal constant LZ_GAS                       = 130_000;
    // Note: option_length = 1 (option type) + 16 (uint128 gas) = 17
    uint16  internal constant LZ_OPTION_LENGTH             = 17;

    function actions() public override {
        // ---------- Wire LZ_GOV_SENDER on Ethereum Mainnet with Avalanche Mainnet ----------
        // Forum: https://forum.skyeco.com/t/skylink-bridge-to-avalanche/27825
        // Poll:

        // Set GovernanceOAppReceiver as a peer on Avalanche by calling LZ_GOV_SENDER.setPeer with:
        // LZ_GOV_SENDER being the address from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setPeer(
            // uint32 _eid being 30106
            AVAX_EID,
            // bytes32 _peer being 0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec padded with zeros
            AVAX_GOV_RECEIVER
        );

        // Set Oapp SendLibrary for Avalanche by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being LZ_GOV_SENDER from chainlog
            LZ_GOV_SENDER,
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Note: Create dynamic array for _params argument in EndpointV2Like(ETH_LZ_ENDPOINT).setConfig():
        EndpointV2Like.SetConfigParam[] memory setConfigParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory govRequiredDVNs = new address[](0);

        // Note: Create dynamic array for optionalDVNs:
        address[] memory govOptionalDVNs = new address[](7);

        // Note: DVN addresses sorted in ascending order
        govOptionalDVNs[0] = 0x06559EE34D85a88317Bf0bfE307444116c631b67; // P2P
        govOptionalDVNs[1] = 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4; // Deutsche Telekom
        govOptionalDVNs[2] = 0x380275805876Ff19055EA900CDb2B46a94ecF20D; // Horizen
        govOptionalDVNs[3] = 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4; // Luganodes
        govOptionalDVNs[4] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        govOptionalDVNs[5] = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd; // Canary
        govOptionalDVNs[6] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        setConfigParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded ExecutorConfig with:
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
        setConfigParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded UlnConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 255 (meaning NONE)
                requiredDVNCount: 255,
                // uint8 optionalDVNCount being 7
                optionalDVNCount: 7,
                // uint8 optionalDVNThreshold being 4
                optionalDVNThreshold: 4,
                // address[] requiredDVNs being an array with 0 addresses
                requiredDVNs: govRequiredDVNs,
                // address[] optionalDVNs being an array with 7 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b (LayerZero Labs), 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5 (Nethermind), 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd (Canary),0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4 (Deutsche Telekom), 0x06559EE34D85a88317Bf0bfE307444116c631b67 (P2P), 0x380275805876Ff19055EA900CDb2B46a94ecF20D (Horizen), 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4 (Luganodes)]
                optionalDVNs: govOptionalDVNs
            }))
        });

        // Configure Oapp SendLibrary for Avalanche by calling EndpointV2.setConfig with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being LZ_GOV_SENDER from chainlog
            LZ_GOV_SENDER,
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // SetConfigParam[] _params being an array with two items:
            // Note: dynamic array previously created
            setConfigParams
        );

        // ---------- Allow LZ_GOV_SENDER to send messages to Avalanche ----------
        // Forum:
        // Poll:

        // Call LZ_GOV_SENDER.setCanCallTarget with:
        // LZ_GOV_SENDER being the address from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            // address _srcSender being LZ_GOV_RELAY from chainlog
            LZ_GOV_RELAY,
            // uint32 _dstEid being 30106
            AVAX_EID,
            // bytes32 _dstTarget being 0xe928885BCe799Ed933651715608155F01abA23cA padded with zeros
            AVAX_L2_GOV_RELAY,
            // bool _canCall being true
            true
        );

        // ---------- Wire USDS_OFT on Ethereum Mainnet with Avalanche Mainnet ----------
        // Forum:
        // Poll:

        // Set SkyOFTAdapterMintBurn(USDS) as a peer on Avalanche by calling USDS_OFT.setPeer with:
        // USDS_OFT being the address from chainlog
        SkyOFTAdapterLike(USDS_OFT).setPeer(
            // uint32 eid being 30106
            AVAX_EID,
            // bytes32 _peer being 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619 padded with zeros
            AVAX_USDS_OFT
        );

        // Set OFT SendLibrary for Avalanche by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being USDS_OFT from chainlog
            USDS_OFT,
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Set OFT ReceiveLibrary for Avalanche by calling EndpointV2.setReceiveLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setReceiveLibrary(
            // address _oapp being USDS_OFT from chainlog
            USDS_OFT,
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // _gracePeriod being 0
            0
        );

        // Note: Create dynamic array for _params argument in EndpointV2Like(ETH_LZ_ENDPOINT).setConfig():
        EndpointV2Like.SetConfigParam[] memory usdsOftSendParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory usdsOftSendRequiredDVNs = new address[](2);

        // Note: DVN addresses sorted in ascending order
        usdsOftSendRequiredDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        usdsOftSendRequiredDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        // Note: Create dynamic array for optionalDVNs:
        address[] memory usdsOftSendOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        usdsOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded ExecutorConfig with:
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
        usdsOftSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded UlnConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                requiredDVNs: usdsOftSendRequiredDVNs,
                optionalDVNs: usdsOftSendOptionalDVNs
            }))
        });

        // Configure OFT SendLibrary for Avalanche by calling EndpointV2.setConfig with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being USDS_OFT from chainlog
            USDS_OFT,
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // SetConfigParam[] _params being an array with two items:
            // Note: dynamic array previously created
            usdsOftSendParams
        );

        // Note: Create dynamic array for _params argument in EndpointV2Like(ETH_LZ_ENDPOINT).setConfig():
        EndpointV2Like.SetConfigParam[] memory usdsOftRecvParams = new EndpointV2Like.SetConfigParam[](1);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory usdsOftRecvRequiredDVNs = new address[](2);

        // Note: DVN addresses sorted in ascending order
        usdsOftRecvRequiredDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        usdsOftRecvRequiredDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        // Note: Create dynamic array for optionalDVNs:
        address[] memory usdsOftRecvOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with one item:
        usdsOftRecvParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded UlnConfig with: (Confirmed by LayerZero)
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 12 (default configuration from source)
                confirmations: 12,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                requiredDVNs: usdsOftRecvRequiredDVNs,
                optionalDVNs: usdsOftRecvOptionalDVNs
            }))
        });

        // Configure OFT ReceiveLibrary for Avalanche by calling EndpointV2.setConfig with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being USDS_OFT from chainlog
            USDS_OFT,
            // address _lib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // SetConfigParam[] _params being an array with one item:
            // Note: dynamic array previously created
            usdsOftRecvParams
        );

        // EnforcedOptionParam[] _enforcedOptions being an array with 2 items:
        // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
        bytes memory usdsOftEnforcedOptionsData = abi.encodePacked(
            LZ_OPTIONS_TYPE_3, LZ_EXECUTOR_WORKER_ID, LZ_OPTION_LENGTH, LZ_OPTION_TYPE_LZRECEIVE, LZ_GAS
        );

        // Note: Create dynamic array for _enforcedOptions argument in SkyOFTAdapterLike(USDS_OFT).setEnforcedOptions():
        SkyOFTAdapterLike.EnforcedOptionParam[] memory usdsOftEnforcedOptions =
            new SkyOFTAdapterLike.EnforcedOptionParam[](2);

        // SendOption (generated with OptionsBuilder.addExecutorLzReceiveOption
        usdsOftEnforcedOptions[0] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint16 msgType being 1 (Meaning SEND)
            msgType: 1,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            options: usdsOftEnforcedOptionsData
        });

        // SendAndCallOption (generated with OptionsBuilder.addExecutorLzReceiveOption)
        usdsOftEnforcedOptions[1] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint16 msgType being 2 (Meaning SEND_AND_CALL)
            msgType: 2,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            options: usdsOftEnforcedOptionsData
        });

        // Set OFT enforced options for Avalanche by calling USDS_OFT.setEnforcedOptions with:
        // USDS_OFT being the address from chainlog
        // Note: enforcedOptions dynamic array previously created
        SkyOFTAdapterLike(USDS_OFT).setEnforcedOptions(usdsOftEnforcedOptions);

        // ---------- Set USDS rate limits for Avalanche ----------
        // Forum:
        // Poll:

        // Note: Create dynamic array for _rateLimitConfigsInbound argument in SkyOFTAdapterLike(USDS_OFT).setRateLimits():
        RateLimitConfig[] memory usdsOftRateLimitConfigsInbound = new RateLimitConfig[](1);
        // Note: Create dynamic array for _rateLimitConfigsOutbound argument in SkyOFTAdapterLike(USDS_OFT).setRateLimits():
        RateLimitConfig[] memory usdsOftRateLimitConfigsOutbound = new RateLimitConfig[](1);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // RateLimitConfig[] _rateLimitConfigsInbound being an array with one item:
        usdsOftRateLimitConfigsInbound[0] = RateLimitConfig({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint48 window being 86,400s (1 day)
            window: 86_400,
            // uint256 limit being 5,000,000 USDS
            limit: 5_000_000 * WAD
        });

        // RateLimitConfig[] _rateLimitConfigsOutbound being an array with one item:
        usdsOftRateLimitConfigsOutbound[0] = RateLimitConfig({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint48 window being 86,400s (1 day)
            window: 86_400,
            // uint256 limit being 5 million USDS
            limit: 5_000_000 * WAD
        });

        // USDS_OFT being the address from chainlog
        SkyOFTAdapterLike(USDS_OFT).setRateLimits(
            // Note: rateLimitConfigsInbound dynamic array previously created
            usdsOftRateLimitConfigsInbound,
            // Note: rateLimitConfigsOutbound dynamic array previously created
            usdsOftRateLimitConfigsOutbound
        );

        // ---------- Add 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1 to chainlog as SUSDS_OFT ----------
        // Forum:
        // Poll:

        DssExecLib.setChangelogAddress("SUSDS_OFT", ETH_SUSDS_OFT);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.15");

        // ---------- Wire SUSDS_OFT on Ethereum Mainnet with Avalanche Mainnet ----------
        // Forum:
        // Poll:

        // Set pauser by calling SUSDS_OFT.setPauser with:
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setPauser(
            // address _pauser being 0x38d1114b4cE3e079CC0f627df6aC2776B5887776
            0x38d1114b4cE3e079CC0f627df6aC2776B5887776,
            // bool _canPause being true
            true
        );

        // Set SkyOFTAdapterMintBurn(sUSDS) as a peer on Avalanche by calling SUSDS_OFT.setPeer with:
        // SUSDS_OFT being the address from chainlog
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setPeer(
            // uint32 eid being 30106
            AVAX_EID,
            // bytes32 _peer being SkyOFTAdapterMintBurn(sUSDS)
            AVAX_SUSDS_OFT
        );

        // Set OFT SendLibrary for Avalanche by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being SUSDS_OFT from chainlog
            DssExecLib.getChangelogAddress("SUSDS_OFT"),
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Set OFT ReceiveLibrary for Avalanche by calling EndpointV2.setReceiveLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setReceiveLibrary(
        // address _oapp being SUSDS_OFT from chainlog
            DssExecLib.getChangelogAddress("SUSDS_OFT"),
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // _gracePeriod being 0
            0
        );

        // Note: Create dynamic array for _params argument in EndpointV2Like(ETH_LZ_ENDPOINT).setConfig():
        EndpointV2Like.SetConfigParam[] memory sUsdsOftSendParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory sUsdsOftSendRequiredDVNs = new address[](2);

        // Note: DVN addresses sorted in ascending order
        sUsdsOftSendRequiredDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        sUsdsOftSendRequiredDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        // Note: Create dynamic array for optionalDVNs:
        address[] memory sUsdsOftSendOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        sUsdsOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded ExecutorConfig with:
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
        sUsdsOftSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded UlnConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs being an array with 2 addresses:
                // 0x589dEDbD617e0CBcB916A9223F4d1300c294236b
                // 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5
                // Note: dynamic array previously created
                requiredDVNs: sUsdsOftSendRequiredDVNs,
                // address[] optionalDVNs being an array with 0 addresses
                // Note: dynamic array previously created
                optionalDVNs: sUsdsOftSendOptionalDVNs
            }))
        });

        // Configure OFT SendLibrary for Avalanche by calling EndpointV2.setConfig with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being SUSDS_OFT from chainlog
            DssExecLib.getChangelogAddress("SUSDS_OFT"),
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // SetConfigParam[] _params being an array with two items:
            // Note: dynamic array previously created
            sUsdsOftSendParams
        );

        // Note: Create dynamic array for _params argument in EndpointV2Like(ETH_LZ_ENDPOINT).setConfig():
        EndpointV2Like.SetConfigParam[] memory sUsdsOftRecvParams = new EndpointV2Like.SetConfigParam[](1);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory sUsdsOftRecvRequiredDVNs = new address[](2);

        // Note: DVN addresses sorted in ascending order
        sUsdsOftRecvRequiredDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        sUsdsOftRecvRequiredDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        // Note: Create dynamic array for optionalDVNs:
        address[] memory sUsdsOftRecvOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with one item:
        sUsdsOftRecvParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded UlnConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 12
                confirmations: 12,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs being an array with 2 addresses:
                // 0x589dEDbD617e0CBcB916A9223F4d1300c294236b
                // 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5
                // Note: dynamic array previously created
                requiredDVNs: sUsdsOftRecvRequiredDVNs,
                // address[] optionalDVNs being an array with 0 addresses
                // Note: dynamic array previously created
                optionalDVNs: sUsdsOftRecvOptionalDVNs
            }))
        });

        // Configure OFT ReceiveLibrary for Avalanche by calling EndpointV2.setConfig with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being SUSDS_OFT from chainlog
            DssExecLib.getChangelogAddress("SUSDS_OFT"),
            // address _lib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // SetConfigParam[] _params being an array with one item:
            // Note: dynamic array previously created
            sUsdsOftRecvParams
        );

        // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
        bytes memory sUsdsOftEnforcedOptionsData = abi.encodePacked(
            LZ_OPTIONS_TYPE_3, LZ_EXECUTOR_WORKER_ID, LZ_OPTION_LENGTH, LZ_OPTION_TYPE_LZRECEIVE, LZ_GAS
        );

        // Note: Create dynamic array for _enforcedOptions argument in SkyOFTAdapterLike(SUSDS_OFT).setEnforcedOptions():
        SkyOFTAdapterLike.EnforcedOptionParam[] memory sUsdsOftEnforcedOptions = new SkyOFTAdapterLike.EnforcedOptionParam[](2);

        // SendOption
        sUsdsOftEnforcedOptions[0] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint16 msgType being 1 (Meaning SEND)
            msgType: 1,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: encoded data generated above
            options: sUsdsOftEnforcedOptionsData
        });

        // SendAndCallOption
        sUsdsOftEnforcedOptions[1] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint16 msgType being 2 (Meaning SEND_AND_CALL)
            msgType: 2,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: encoded data generated above
            options: sUsdsOftEnforcedOptionsData
        });

        // Set OFT enforced options for Avalanche by calling SUSDS_OFT.setEnforcedOptions with:
        // SUSDS_OFT being the address from chainlog
        // Note: sUsdsOftEnforcedOptions dynamic array previously created
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setEnforcedOptions(sUsdsOftEnforcedOptions);

        // ---------- Staking Rewards Update ----------
        // Forum:
        // Poll:

        // TODO

        // ---------- Grove Genesis Capital Transfer ----------
        // Forum:
        // Poll:

        // TODO

        // ---------- Safe Harbor Update ----------
        // Forum:
        // Poll:

        // TODO

        // ---------- Spark Proxy Spell ----------
        // Forum:
        // Poll:

        // Whitelist Spark spell with address 0xFa5fc020311fCC1A467FEC5886640c7dD746deAa and codehash 0x2572a97846f7a6f9f159a9a69c2707cfa4186c061de2a0ec59e7a0d46473c74c in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum:
        // Poll:

        // Whitelist Grove spell with address 0x679eD4739c71300f7d78102AE5eE17EF8b8b2162 and codehash 0x4fa1f743b3d6d2855390724459129186dd684e1c07d59f88925f0059ba1e6c84 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
