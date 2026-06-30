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
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import {TreasuryFundedFarmingInit, FarmingUpdateVestParams} from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

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
    function plot(address addr_, bytes32 tag_) external;
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/656d5a6d9e8041203d98823248e64d87771681d3/2026/executive-vote-2026-04-09-launch-avalanche-skylink-staking-rewards-update.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-04-09 MakerDAO Executive Spell | Hash: 0x0f87466f280de3544ae715fb2463152d7959c37902926f2069aaaccf10cef550";

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
    uint256 internal constant WAD = 10 ** 18;

    // ---------- Contracts ----------
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable LZ_GOV_SENDER            = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable LZ_GOV_RELAY             = DssExecLib.getChangelogAddress("LZ_GOV_RELAY");
    address internal immutable USDS_OFT                 = DssExecLib.getChangelogAddress("USDS_OFT");
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable REWARDS_DIST_LSSKY_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable GROVE_SUBPROXY           = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable SAFE_HARBOR_AGREEMENT    = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");

    // ---------- Addresses ----------
    address internal constant SUSDS_OFT_PAUSER = 0x38d1114b4cE3e079CC0f627df6aC2776B5887776;

    // ---------- DVNs ----------
    address internal constant P2P               = 0x06559EE34D85a88317Bf0bfE307444116c631b67;
    address internal constant DEUTSCHE_TELEKOM  = 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4;
    address internal constant HORIZEN           = 0x380275805876Ff19055EA900CDb2B46a94ecF20D;
    address internal constant LUGANODES         = 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4;
    address internal constant LAYERZERO_LABS    = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    address internal constant CANARY            = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd;
    address internal constant NETHERMIND        = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;

    // ---------- LayerZero ----------
    address internal constant ETH_LZ_ENDPOINT   = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant ETH_LZ_SEND_302   = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
    address internal constant ETH_LZ_RECV_302   = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
    address internal constant ETH_LZ_EXECUTOR   = 0x173272739Bd7Aa6e4e214714048a9fE699453059;
    address internal constant ETH_SUSDS_OFT     = 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1;

    uint32  internal constant AVAX_EID          = 30106;
    address internal constant AVAX_GOV_RECEIVER = 0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec;
    address internal constant AVAX_L2_GOV_RELAY = 0xe928885BCe799Ed933651715608155F01abA23cA;
    address internal constant AVAX_USDS_OFT     = 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619;
    address internal constant AVAX_SUSDS_OFT    = 0x7297D4811f088FC26bC5475681405B99b41E1FF9;

    // ---------- Spark ----------
    address internal constant SPARK_SPELL      = 0xFa5fc020311fCC1A467FEC5886640c7dD746deAa;
    bytes32 internal constant SPARK_SPELL_HASH = 0x2572a97846f7a6f9f159a9a69c2707cfa4186c061de2a0ec59e7a0d46473c74c;

    // ---------- Grove ----------
    address internal constant GROVE_SPELL      = 0x679eD4739c71300f7d78102AE5eE17EF8b8b2162;
    bytes32 internal constant GROVE_SPELL_HASH = 0x4fa1f743b3d6d2855390724459129186dd684e1c07d59f88925f0059ba1e6c84;

    // Note: OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0) constants (0003010011010000000000000000000000000001fbd0)
    uint16 internal constant LZ_OPTIONS_TYPE_3             = 3; // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L22
    uint8  internal constant LZ_EXECUTOR_WORKER_ID         = 1; // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L10
    uint8  internal constant LZ_OPTION_TYPE_LZRECEIVE      = 1; // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L12
    uint128 internal constant LZ_GAS                       = 130_000;
    // Note: LZ_OPTION_LENGTH = 1 (LZ_OPTION_TYPE_LZRECEIVE, uint8) + 16 (LZ_GAS, uint128) = 17
    uint16  internal constant LZ_OPTION_LENGTH             = 17;

    function actions() public override {
        // ---------- Launch Avalanche SkyLink ----------
        // Forum: https://forum.skyeco.com/t/skylink-bridge-to-avalanche/27825

        // Wire LZ_GOV_SENDER on Ethereum Mainnet with Avalanche Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set GovernanceOAppReceiver as a peer on Avalanche by calling LZ_GOV_SENDER.setPeer with:
        // LZ_GOV_SENDER being the address from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setPeer(
            // uint32 _eid being 30106
            AVAX_EID,
            // bytes32 _peer being 0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec padded with zeros
            bytes32(uint256(uint160(AVAX_GOV_RECEIVER)))
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
        EndpointV2Like.SetConfigParam[] memory govOappSendParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for requiredDVNs:
        address[] memory govOappRequiredDVNs = new address[](0);

        // Note: Create dynamic array for optionalDVNs:
        address[] memory govOappOptionalDVNs = new address[](7);

        // Note: DVN addresses sorted in ascending order
        govOappOptionalDVNs[0] = P2P;
        govOappOptionalDVNs[1] = DEUTSCHE_TELEKOM;
        govOappOptionalDVNs[2] = HORIZEN;
        govOappOptionalDVNs[3] = LUGANODES;
        govOappOptionalDVNs[4] = LAYERZERO_LABS;
        govOappOptionalDVNs[5] = CANARY;
        govOappOptionalDVNs[6] = NETHERMIND;

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        govOappSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L16
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
        govOappSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17
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
                // Note: dynamic array previously created
                requiredDVNs: govOappRequiredDVNs,
                // address[] optionalDVNs being an array with 7 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5, 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd, 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4, 0x06559EE34D85a88317Bf0bfE307444116c631b67, 0x380275805876Ff19055EA900CDb2B46a94ecF20D, 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4]
                // Note: dynamic array previously created
                optionalDVNs: govOappOptionalDVNs
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
            govOappSendParams
        );

        // Allow LZ_GOV_SENDER to send messages to Avalanche
        // Note: This is only a subheading, actual instructions follow below.

        // Call LZ_GOV_SENDER.setCanCallTarget with:
        // LZ_GOV_SENDER being the address from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            // address _srcSender being LZ_GOV_RELAY from chainlog
            LZ_GOV_RELAY,
            // uint32 _dstEid being 30106
            AVAX_EID,
            // bytes32 _dstTarget being 0xe928885BCe799Ed933651715608155F01abA23cA padded with zeros
            bytes32(uint256(uint160(AVAX_L2_GOV_RELAY))),
            // bool _canCall being true
            true
        );

        // Wire USDS_OFT on Ethereum Mainnet with Avalanche Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set SkyOFTAdapterMintBurn(USDS) as a peer on Avalanche by calling USDS_OFT.setPeer with:
        // USDS_OFT being the address from chainlog
        SkyOFTAdapterLike(USDS_OFT).setPeer(
            // uint32 eid being 30106
            AVAX_EID,
            // bytes32 _peer being 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619 padded with zeros
            bytes32(uint256(uint160(AVAX_USDS_OFT)))
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
        usdsOftSendRequiredDVNs[0] = LAYERZERO_LABS;
        usdsOftSendRequiredDVNs[1] = NETHERMIND;

        // Note: Create dynamic array for optionalDVNs:
        address[] memory usdsOftSendOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        usdsOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L16
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
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17
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
                // address[] requiredDVNs being an array with 2 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                // Note: dynamic array previously created
                requiredDVNs: usdsOftSendRequiredDVNs,
                // address[] optionalDVNs being an array with 0 addresses
                // Note: dynamic array previously created
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
        usdsOftRecvRequiredDVNs[0] = LAYERZERO_LABS;
        usdsOftRecvRequiredDVNs[1] = NETHERMIND;

        // Note: Create dynamic array for optionalDVNs:
        address[] memory usdsOftRecvOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with one item:
        usdsOftRecvParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17
            configType: 2,
            // bytes config being encoded UlnConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 12 (default configuration from source)
                confirmations: 12,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs being an array with 2 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                // Note: dynamic array previously created
                requiredDVNs: usdsOftRecvRequiredDVNs,
                // address[] optionalDVNs being an array with 0 addresses
                // Note: dynamic array previously created
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
        // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L53
        bytes memory enforcedOptionsData = abi.encodePacked(
            LZ_OPTIONS_TYPE_3, LZ_EXECUTOR_WORKER_ID, LZ_OPTION_LENGTH, LZ_OPTION_TYPE_LZRECEIVE, LZ_GAS
        );

        // Note: Create dynamic array for _enforcedOptions argument in SkyOFTAdapterLike(USDS_OFT).setEnforcedOptions():
        SkyOFTAdapterLike.EnforcedOptionParam[] memory usdsOftEnforcedOptions =
            new SkyOFTAdapterLike.EnforcedOptionParam[](2);

        // SendOption (generated with OptionsBuilder.addExecutorLzReceiveOption)
        usdsOftEnforcedOptions[0] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint16 msgType being 1 (Meaning SEND)
            msgType: 1,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: encoded data generated above
            options: enforcedOptionsData
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
            // Note: encoded data generated above
            options: enforcedOptionsData
        });

        // Set OFT enforced options for Avalanche by calling USDS_OFT.setEnforcedOptions with:
        // USDS_OFT being the address from chainlog
        // Note: enforcedOptions dynamic array previously created
        SkyOFTAdapterLike(USDS_OFT).setEnforcedOptions(usdsOftEnforcedOptions);

        // Set USDS rate limits for Avalanche
        // Note: This is only a subheading, actual instructions follow below.

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

        // Add 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1 to chainlog as SUSDS_OFT
        DssExecLib.setChangelogAddress("SUSDS_OFT", ETH_SUSDS_OFT);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.15");

        // Wire SUSDS_OFT on Ethereum Mainnet with Avalanche Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set pauser by calling SUSDS_OFT.setPauser with:
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setPauser(
            // address _pauser being 0x38d1114b4cE3e079CC0f627df6aC2776B5887776
            SUSDS_OFT_PAUSER,
            // bool _canPause being true
            true
        );

        // Set SkyOFTAdapterMintBurn(sUSDS) as a peer on Avalanche by calling SUSDS_OFT.setPeer with:
        // SUSDS_OFT being the address from chainlog
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setPeer(
            // uint32 eid being 30106
            AVAX_EID,
            // bytes32 _peer being SkyOFTAdapterMintBurn(sUSDS)
            bytes32(uint256(uint160(AVAX_SUSDS_OFT)))
        );

        // Set OFT SendLibrary for Avalanche by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being SUSDS_OFT from chainlog
            ETH_SUSDS_OFT,
            // uint32 _eid being 30106
            AVAX_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Set OFT ReceiveLibrary for Avalanche by calling EndpointV2.setReceiveLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setReceiveLibrary(
        // address _oapp being SUSDS_OFT from chainlog
            ETH_SUSDS_OFT,
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
        sUsdsOftSendRequiredDVNs[0] = LAYERZERO_LABS;
        sUsdsOftSendRequiredDVNs[1] = NETHERMIND;

        // Note: Create dynamic array for optionalDVNs:
        address[] memory sUsdsOftSendOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with two items:
        // First item: Executor parameters
        sUsdsOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 1
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L16
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
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17
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
                // address[] requiredDVNs being an array with 2 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
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
            ETH_SUSDS_OFT,
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
        sUsdsOftRecvRequiredDVNs[0] = LAYERZERO_LABS;
        sUsdsOftRecvRequiredDVNs[1] = NETHERMIND;

        // Note: Create dynamic array for optionalDVNs:
        address[] memory sUsdsOftRecvOptionalDVNs = new address[](0);

        // Note: altered order because dynamic arrays cannot be declared in the argument of the function call:
        // SetConfigParam[] _params being an array with one item:
        sUsdsOftRecvParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30106
            eid: AVAX_EID,
            // uint32 configType being 2
            // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/uln/uln302/SendUln302.sol#L17
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
                // address[] requiredDVNs being an array with 2 addresses: [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
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
            ETH_SUSDS_OFT,
            // address _lib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // SetConfigParam[] _params being an array with one item:
            // Note: dynamic array previously created
            sUsdsOftRecvParams
        );

        // EnforcedOptionParam[] _enforcedOptions being an array with 2 items:
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
            options: enforcedOptionsData
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
            options: enforcedOptionsData
        });

        // Set OFT enforced options for Avalanche by calling SUSDS_OFT.setEnforcedOptions with:
        // SUSDS_OFT being the address from chainlog
        // Note: sUsdsOftEnforcedOptions dynamic array previously created
        SkyOFTAdapterLike(ETH_SUSDS_OFT).setEnforcedOptions(sUsdsOftEnforcedOptions);

        // ---------- Staking Rewards Update ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/6
        // Poll: https://vote.sky.money/polling/QmW61Lnd

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 192,110,322 SKY
            vestTot: 192_110_322 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- Grove Genesis Capital Transfer ----------
        // Forum: https://forum.skyeco.com/t/grove-genesis-capital-transfer/27828
        // Atlas: https://sky-atlas.io/#062fdb39-464e-4a5b-a44f-3462d2d38be5
        // Atlas: https://sky-atlas.io/#5a62cc3f-4337-4770-a4d1-8a9b3d158b3f

        // Transfer 20,797,477 USDS to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 20_797_477 * WAD);

        // ---------- Safe Harbor Update ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        // ---------- Bug Bounty Updates ----------
        bytes[] memory calldatas = new bytes[](2);

        // Add new eip155:43114 with recovery address 0xe928885BCe799Ed933651715608155F01abA23cA and accounts: 0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec, 0xe928885BCe799Ed933651715608155F01abA23cA, 0xB5bc5dFe65a9ec30738DB3a0b592B8a18A191300, 0x86Ff09db814ac346a7C6FE2Cd648F27706D1D470, 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619, 0xc8dB83458e8593Ed9a2D81DC29068B12D330729a, 0xb94D9613C7aAB11E548a327154Cc80eCa911B5c1, 0x7297D4811f088FC26bC5475681405B99b41E1FF9
        calldatas[0] = hex'be4a94ba000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000006e0000000000000000000000000000000000000000000000000000000000000002a307865393238383835424365373939456439333336353137313536303831353546303161624132336341000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000002e00000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078366664643436393437636136393033633863313539643164463230313242633766433563456565630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078653932383838354243653739394564393333363531373135363038313535463031616241323363410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078423562633564466536356139656333303733384442336130623539324238613138413139313330300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078383646663039646238313461633334366137433646453243643634384632373730364431443437300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078346665633430373139664439613841453346384532303533313636394445433539363244323631390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078633864423833343538653835393345643961324438314443323930363842313244333330373239610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078623934443936313343376141423131453534386133323731353443633830654361393131423563310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783732393744343831316630383846433236624335343735363831343035423939623431453146463900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c6569703135353a34333131340000000000000000000000000000000000000000';

        // Add accounts to eip155:1 chain: 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1
        calldatas[1] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783835413346453444413261366342393841356264463632343538423064423834373142396630663100000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-9-2026-proposed-changes-to-spark-for-upcoming-spell/27804
        // Atlas: https://sky-atlas.io/#A.6.1.1.1.2.6.1.2.1.2.3
        // Poll: https://snapshot.box/#/s:sparkfi.eth/proposal/0x6c889e7be8fba52d9cac4bd2e89c9bcb4ee1952afb40b555e87bf09062cb837f
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x51bf5882e51b16c35ea596cf0ca69d52aeec912c1a72b84b6512d2d5f07a0167

        // Whitelist Spark spell with address 0xFa5fc020311fCC1A467FEC5886640c7dD746deAa and codehash 0x2572a97846f7a6f9f159a9a69c2707cfa4186c061de2a0ec59e7a0d46473c74c in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-9th-2026-proposed-changes-to-grove-for-upcoming-spell/27801
        // Poll: https://vote.sky.money/polling/QmafyxBw

        // Whitelist Grove spell with address 0x679eD4739c71300f7d78102AE5eE17EF8b8b2162 and codehash 0x4fa1f743b3d6d2855390724459129186dd684e1c07d59f88925f0059ba1e6c84 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);
    }

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
    /// @param usr The USDS receiver.
    /// @param wad The USDS amount in wad precision (10 ** 18).
    function _transferUsds(address usr, uint256 wad) internal {
        // Note: Enforce whole units to avoid rounding errors
        require(wad % WAD == 0, "transferUsds/non-integer-wad");
        // Note: DssExecLib currently only supports Dai transfers from the surplus buffer.
        DssExecLib.sendPaymentFromSurplusBuffer(address(this), wad / WAD);
        // Note: Approve DAI_USDS for the amount sent to be able to convert it.
        GemAbstract(DAI).approve(DAI_USDS, wad);
        // Note: Convert Dai to USDS for `usr`.
        DaiUsdsLike(DAI_USDS).daiToUsds(usr, wad);
    }

    /// @notice Wraps the operations required to update the Safe Harbor agreement.
    /// @dev This function executes pre-encoded function calls on the Safe Harbor agreement contract.
    ///      The calldatas array contains ABI-encoded function calls (selector + parameters) that
    ///      will be executed sequentially on the Safe Harbor agreement contract.
    /// @param calldatas Array of ABI-encoded function calls to execute on the Safe Harbor agreement contract
    function _updateSafeHarbor(bytes[] memory calldatas) internal {
        for (uint256 i = 0; i < calldatas.length; i++) {
            (bool success,) = SAFE_HARBOR_AGREEMENT.call(calldatas[i]);
            require(success, "updateSafeHarbor/safe-harbor-update-failed");
        }
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
