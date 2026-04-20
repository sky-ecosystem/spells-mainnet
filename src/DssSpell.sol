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
import { JugAbstract } from "dss-interfaces/dss/JugAbstract.sol";
import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";
import { GemAbstract } from "dss-interfaces/ERC/GemAbstract.sol";
// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)
import {TreasuryFundedFarmingInit, FarmingUpdateVestParams} from "./dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol";

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface DssLitePsmLike {
    function kiss(address usr) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

/** SkyLink related Interface */
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


contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'TODO' -q -O - 2>/dev/null)"
    string public constant override description = "2026-04-23 MakerDAO Executive Spell | Hash: TODO";

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
    uint256 internal constant MILLION = 10 ** 6;
    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable LZ_GOV_SENDER            = DssExecLib.getChangelogAddress("LZ_GOV_SENDER");
    address internal immutable LZ_GOV_RELAY             = DssExecLib.getChangelogAddress("LZ_GOV_RELAY");
    address internal immutable USDS_OFT                 = DssExecLib.getChangelogAddress("USDS_OFT");
    address internal immutable SUSDS_OFT                = DssExecLib.getChangelogAddress("SUSDS_OFT");
    address internal immutable MCD_JUG                  = DssExecLib.jug();
    address internal immutable MCD_VAT                  = DssExecLib.vat();
    address internal immutable MCD_VOW                  = DssExecLib.vow();
    address internal immutable DAI_USDS                 = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable DAI                      = DssExecLib.dai();
    address internal immutable SKYBASE_SUBPROXY         = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable PATTERN_SUBPROXY         = DssExecLib.getChangelogAddress("PATTERN_SUBPROXY");
    address internal immutable SPARK_SUBPROXY           = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable GROVE_SUBPROXY           = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY            = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable OBEX_SUBPROXY            = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable ALLOCATOR_SPARK_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT  = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable ALLOCATOR_OBEX_A_VAULT   = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable REWARDS_DIST_LSSKY_SKY   = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable MCD_LITE_PSM_USDC_A      = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable SPARK_STARGUARD          = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD          = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable PATTERN_STARGUARD        = DssExecLib.getChangelogAddress("PATTERN_STARGUARD");
    address internal constant  PATTERN_ALM_PROXY        = 0xbA43325E91C79E500486a23E953ab3d8C46f169F;

    // ---------- Wallets ----------
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG   = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
    address internal constant CORE_COUNCIL_DELEGATE_MULTISIG = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;

    // ---------- SkyLink ----------
    address internal constant ETH_LZ_ENDPOINT  = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant ETH_LZ_SEND_302  = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
    address internal constant ETH_LZ_RECV_302  = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
    address internal constant ETH_LZ_EXECUTOR  = 0x173272739Bd7Aa6e4e214714048a9fE699453059;

    address internal constant PLASMA_GOV_RECEIVER  = 0x2172120c774510F9b0deDb5378a17A4b7E822C35;
    address internal constant PLASMA_L2_GOV_RELAY  = 0x5CE28f2dD353945db9AB3273A2a1dD1AB632e24b;
    address internal constant PLASMA_USDS_OFT      = 0x8544b2E758E56B8B45909435bE6EA3E8e8500Cf1;
    address internal constant PLASMA_SUSDS_OFT     = 0xb6e64c49C335E507DBa8Dd7b05bC6c9FbAdCE601;

    address internal constant P2P               = 0x06559EE34D85a88317Bf0bfE307444116c631b67;
    address internal constant DEUTSCHE_TELEKOM  = 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4;
    address internal constant HORIZEN           = 0x380275805876Ff19055EA900CDb2B46a94ecF20D;
    address internal constant LUGANODES         = 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4;
    address internal constant LAYERZERO_LABS    = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    address internal constant CANARY            = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd;
    address internal constant NETHERMIND        = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL = 0x160158d029697FEa486dF8968f3Be17a706dF0F0;
    bytes32 internal constant SPARK_SPELL_HASH = 0x96a0d4068774d80f3790f489aa1bbd37e45d6a019161743ad00eaf61e26466b6;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL = 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929;
    bytes32 internal constant GROVE_SPELL_HASH = 0x43fa1611223445715e33c2ad7baf836cb4c8a00a0ede6fff428b742baefa12c6;

    // ---------- Pattern Spell ----------
    address internal constant PATTERN_SPELL = 0x31831aE3C13f72afcCcf0aAF49b6f9319ed9C4C0;
    bytes32 internal constant PATTERN_SPELL_HASH = 0x1478866625ae91e3ca50fa4ff871f5721862e24b9428f15f49b093cc3305587b;

    // ---------- SkyLink related constants ----------
    uint32  internal constant PLASMA_EID             = 30383;
    // Note: [LZ_OPTIONS_TYPE_3](https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L22)
    uint16 constant internal LZ_OPTIONS_TYPE_3       = 3;
    // Note: [LZ_EXECUTOR_WORKER_ID](https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L10)
    uint8 constant internal LZ_EXECUTOR_WORKER_ID    = 1;
    // Note: [LZ_OPTION_TYPE_LZRECEIVE](https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol#L12)
    uint8 constant internal LZ_OPTION_TYPE_LZRECEIVE = 1;

    function actions() public override {
        // ---------- Launch Plasma SkyLink ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-skylink-bridge-to-plasma/27850

        // Wire LZ_GOV_SENDER on Ethereum Mainnet with Plasma Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set GovernanceOAppReceiver as a peer on Plasma by calling LZ_GOV_SENDER.setPeer with:
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setPeer(
            // uint32 _eid being 30383
            PLASMA_EID,
            // bytes32 _peer being 0x2172120c774510F9b0deDb5378a17A4b7E822C35 padded with zeros
            bytes32(uint256(uint160(PLASMA_GOV_RECEIVER)))
        );

        // Set OApp SendLibrary for Plasma by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being LZ_GOV_SENDER (0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA) from chainlog
            LZ_GOV_SENDER,
            // uint32 _eid being 30383
            PLASMA_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Configure OApp SendLibrary for Plasma by calling EndpointV2.setConfig with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // SetConfigParam[] _params being an array with two items:
        EndpointV2Like.SetConfigParam[] memory govOappSendParams = new EndpointV2Like.SetConfigParam[](2);

        // First item: Executor parameters
        govOappSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded (abi.encode()) ExecutorConfig with:
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
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

        // Note: create send params ULN config
        govOappSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded (abi.encode()) ULNConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 255 (NONE)
                requiredDVNCount: 255,
                // uint8 optionalDVNCount being 7
                optionalDVNCount: 7,
                // uint8 optionalDVNThreshold being 4
                optionalDVNThreshold: 4,
                // address[] requiredDVNs: none
                requiredDVNs: new address[](0),
                // address[] optionalDVNs (7 addresses on Ethereum): [0x06559EE34D85a88317Bf0bfE307444116c631b67, 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4, 0x380275805876Ff19055EA900CDb2B46a94ecF20D, 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4, 0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                optionalDVNs: govOappOptionalDVNs
            }))
        });

        // Note: calling EndpointV2.setConfig with config parameters created above
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being LZ_GOV_SENDER (0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA) from chainlog
            LZ_GOV_SENDER,
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // Note: SetConfigParam array created above
            govOappSendParams
        );

        // Allow LZ_GOV_SENDER to send messages to Plasma
        // Note: This is only a subheading, actual instructions follow below.

        // Call LZ_GOV_SENDER.setCanCallTarget with:
        // LZ_GOV_SENDER being 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA from chainlog
        GovernanceOAppSenderLike(LZ_GOV_SENDER).setCanCallTarget(
            // address _srcSender being 0x2beBFe397D497b66cB14461cB6ee467b4C3B7D61 (LZ_GOV_RELAY from chainlog)
            LZ_GOV_RELAY,
            // uint32 _dstEid being 30383
            PLASMA_EID,
            // bytes32 _dstTarget being 0x5CE28f2dD353945db9AB3273A2a1dD1AB632e24b padded with zeros
            bytes32(uint256(uint160(PLASMA_L2_GOV_RELAY))),
            // bool _canCall being true
            true
        );

        // Wire USDS_OFT on Ethereum Mainnet with Plasma Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set SkyOFTAdapterMintBurn(USDS) as a peer by calling USDS_OFT.setPeer with:
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        SkyOFTAdapterLike(USDS_OFT).setPeer(
            // uint32 _eid being 30383
            PLASMA_EID,
            // bytes32 _peer being 0x8544b2E758E56B8B45909435bE6EA3E8e8500Cf1 padded with zeros
            bytes32(uint256(uint160(PLASMA_USDS_OFT)))
        );

        // Set OFT SendLibrary for Plasma by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being USDS_OFT (0x1e1D42781FC170EF9da004Fb735f56F0276d01B8) from chainlog
            USDS_OFT,
            // uint32 _eid being 30383
            PLASMA_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Set OFT ReceiveLibrary for Plasma by calling EndpointV2.setReceiveLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setReceiveLibrary(
            // address _oapp being USDS_OFT (0x1e1D42781FC170EF9da004Fb735f56F0276d01B8) from chainlog
            USDS_OFT,
            // uint32 _eid being 30383
            PLASMA_EID,
            // address _newLib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // _gracePeriod being 0
            0
        );

        // Configure OFT SendLibrary for Plasma by calling EndpointV2.setConfig with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // SetConfigParam[] _params being an array with two items:
        EndpointV2Like.SetConfigParam[] memory usdsOftSendParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for dvns:
        address[] memory usdsOftRequiredDVNs = new address[](2);
        usdsOftRequiredDVNs[0] = LAYERZERO_LABS;
        usdsOftRequiredDVNs[1] = NETHERMIND;

        // First item: Executor parameters
        usdsOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded (abi.encode()) ExecutorConfig with: (To be confirmed by LayerZero)
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
        usdsOftSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded (abi.encode()) ULNConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0 (default value for the library, current default value is 0)
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs (2 addresses on Ethereum): [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                requiredDVNs: usdsOftRequiredDVNs,
                // address[] optionalDVNs: none
                optionalDVNs: new address[](0)
            }))
        });

        // Note: calling EndpointV2.setConfig with config parameters created above
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being USDS_OFT (0x1e1D42781FC170EF9da004Fb735f56F0276d01B8) from chainlog
            USDS_OFT,
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // Note: SetConfigParam array created above
            usdsOftSendParams
        );

        // Configure OFT ReceiveLibrary for Plasma by calling EndpointV2.setConfig with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // SetConfigParam[] _params being an array with one item (ULN parameters):
        EndpointV2Like.SetConfigParam[] memory usdsOftReceiveParams = new EndpointV2Like.SetConfigParam[](1);
        usdsOftReceiveParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded (abi.encode()) ULNConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 5
                confirmations: 5,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs (2 addresses on Ethereum): [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                requiredDVNs: usdsOftRequiredDVNs,
                // address[] optionalDVNs: none
                optionalDVNs: new address[](0)
            }))
        });

        // Note: calling EndpointV2.setConfig with config parameters created above
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being USDS_OFT (0x1e1D42781FC170EF9da004Fb735f56F0276d01B8) from chainlog
            USDS_OFT,
            // address _lib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // Note: SetConfigParam array created above
            usdsOftReceiveParams
        );

        // Set OFT enforced options for Plasma by calling USDS_OFT.setEnforcedOptions with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // EnforcedOptionParam[] with two items:
        SkyOFTAdapterLike.EnforcedOptionParam[] memory usdsOftEnforcedOptions = new SkyOFTAdapterLike.EnforcedOptionParam[](2);

        // SendOption
        usdsOftEnforcedOptions[0] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30383 (Plasma Mainnet Eid from the docs)
            eid: PLASMA_EID,
            // uint16 msgType being 1 (Meaning SEND)
            msgType: 1,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
            options: _getEnforcedOptions(130_000)
        });

        // SendAndCallOption
        usdsOftEnforcedOptions[1] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint16 msgType being 2 (Meaning SEND_AND_CALL)
            msgType: 2,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
            options: _getEnforcedOptions(130_000)
        });

        // Note: calling USDS_OFT.setEnforcedOptions with config created above
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        SkyOFTAdapterLike(USDS_OFT).setEnforcedOptions(usdsOftEnforcedOptions);

        // Set USDS rate limits for Plasma
        // Note: This is only a subheading, actual instructions follow below.

        // Call USDS_OFT.setRateLimits with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // RateLimitConfig[] _rateLimitConfigsInbound being an array with one item:
        RateLimitConfig[] memory usdsOftRateLimitConfigsInbound = new RateLimitConfig[](1);
        usdsOftRateLimitConfigsInbound[0] = RateLimitConfig({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint48 window being 86,400 (1 day)
            window: 86_400,
            // uint256 limit being 5,000,000 USDS
            limit: 5_000_000 * WAD
        });

        // RateLimitConfig[] _rateLimitConfigsOutbound being an array with one item:
        RateLimitConfig[] memory usdsOftRateLimitConfigsOutbound = new RateLimitConfig[](1);
        usdsOftRateLimitConfigsOutbound[0] = RateLimitConfig({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint48 window being 86,400 (1 day)
            window: 86_400,
            // uint256 limit being 5,000,000 USDS
            limit: 5_000_000 * WAD
        });

        // Note: call USDS_OFT.setRateLimits with configs created above
        // USDS_OFT being 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8 from chainlog
        SkyOFTAdapterLike(USDS_OFT).setRateLimits(usdsOftRateLimitConfigsInbound, usdsOftRateLimitConfigsOutbound);

        // Wire SUSDS_OFT on Ethereum Mainnet with Plasma Mainnet
        // Note: This is only a subheading, actual instructions follow below.

        // Set SkyOFTAdapterMintBurn(sUSDS) as a peer by calling SUSDS_OFT.setPeer with:
        // SUSDS_OFT being 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1 from chainlog
        SkyOFTAdapterLike(SUSDS_OFT).setPeer(
            // uint32 _eid being 30383
            PLASMA_EID,
            // bytes32 _peer being 0xb6e64c49C335E507DBa8Dd7b05bC6c9FbAdCE601 padded with zeros
            bytes32(uint256(uint160(PLASMA_SUSDS_OFT)))
        );

        // Set OFT SendLibrary for Plasma by calling EndpointV2.setSendLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setSendLibrary(
            // address _oapp being SUSDS_OFT (0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1) from chainlog
            SUSDS_OFT,
            // uint32 _eid being 30383
            PLASMA_EID,
            // address _newLib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302
        );

        // Set OFT ReceiveLibrary for Plasma by calling EndpointV2.setReceiveLibrary with:
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setReceiveLibrary(
            // address _oapp being SUSDS_OFT (0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1) from chainlog
            SUSDS_OFT,
            // uint32 _eid being 30383
            PLASMA_EID,
            // address _newLib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2
            ETH_LZ_RECV_302,
            // _gracePeriod being 0
            0
        );

        // Configure OFT SendLibrary for Plasma by calling EndpointV2.setConfig with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // SetConfigParam[] _params being an array with two items:
        EndpointV2Like.SetConfigParam[] memory susdOftSendParams = new EndpointV2Like.SetConfigParam[](2);

        // Note: Create dynamic array for dvns:
        address[] memory susdOftRequiredDVNs = new address[](2);
        susdOftRequiredDVNs[0] = LAYERZERO_LABS;
        susdOftRequiredDVNs[1] = NETHERMIND;

        // First item: Executor parameters
        susdOftSendParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 1
            configType: 1,
            // bytes config being encoded (abi.encode()) ExecutorConfig with:
            config: abi.encode(ExecutorConfig({
                // maxMessageSize being 10_000
                maxMessageSize: 10_000,
                // executor being 0x173272739Bd7Aa6e4e214714048a9fE699453059
                executor: ETH_LZ_EXECUTOR
            }))
        });

        // Second item: ULN parameters
        susdOftSendParams[1] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded (abi.encode()) ULNConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 15
                confirmations: 15,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0 (default value for the library, current default value is 0)
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs (2 addresses on Ethereum): [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                requiredDVNs: susdOftRequiredDVNs,
                // address[] optionalDVNs: none
                optionalDVNs: new address[](0)
            }))
        });

        // Note: calling EndpointV2.setConfig with config parameters created above
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being SUSDS_OFT (0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1) from chainlog
            SUSDS_OFT,
            // address _lib being 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
            ETH_LZ_SEND_302,
            // Note: SetConfigParam array created above
            susdOftSendParams
        );

        // Configure OFT ReceiveLibrary for Plasma by calling EndpointV2.setConfig with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // SetConfigParam[] _params being an array with one item (ULN parameters):
        EndpointV2Like.SetConfigParam[] memory susdOftReceiveParams = new EndpointV2Like.SetConfigParam[](1);
        susdOftReceiveParams[0] = EndpointV2Like.SetConfigParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint32 configType being 2
            configType: 2,
            // bytes config being encoded (abi.encode()) ULNConfig with:
            config: abi.encode(UlnConfig({
                // uint64 confirmations being 5
                confirmations: 5,
                // uint8 requiredDVNCount being 2
                requiredDVNCount: 2,
                // uint8 optionalDVNCount being 0 (default value for the library, current default value is 0)
                optionalDVNCount: 0,
                // uint8 optionalDVNThreshold being 0
                optionalDVNThreshold: 0,
                // address[] requiredDVNs (2 addresses on Ethereum): [0x589dEDbD617e0CBcB916A9223F4d1300c294236b, 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5]
                requiredDVNs: susdOftRequiredDVNs,
                // address[] optionalDVNs: none
                optionalDVNs: new address[](0)
            }))
        });

        // Note: calling EndpointV2.setConfig with config parameters created above
        // EndpointV2 being 0x1a44076050125825900e736c501f859c50fE728c
        EndpointV2Like(ETH_LZ_ENDPOINT).setConfig(
            // address _oapp being SUSDS_OFT (0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1) from chainlog
            SUSDS_OFT,
            // address _lib being 0xc02Ab410f0734EFa3F14628780e6e695156024C2 (ReceiveUln302 on Ethereum)
            ETH_LZ_RECV_302,
            // Note: SetConfigParam array created above
            susdOftReceiveParams
        );

        // Set OFT enforced options for Plasma by calling SUSDS_OFT.setEnforcedOptions with:
        // Note: dynamic array config is created before calling function and comment order has been changed to accommodate to this

        // EnforcedOptionParam[] with two items:
        SkyOFTAdapterLike.EnforcedOptionParam[] memory susdOftEnforcedOptions = new SkyOFTAdapterLike.EnforcedOptionParam[](2);

        // SendOption
        susdOftEnforcedOptions[0] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint16 msgType being 1 (Meaning SEND)
            msgType: 1,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
            options: _getEnforcedOptions(130_000)
        });

        // SendAndCallOption
        susdOftEnforcedOptions[1] = SkyOFTAdapterLike.EnforcedOptionParam({
            // uint32 eid being 30383
            eid: PLASMA_EID,
            // uint16 msgType being 2 (Meaning SEND_AND_CALL)
            msgType: 2,
            // bytes options being encoded:
            // uint128 _gas being 130_000
            // uint128 _value being 0
            // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: 130_000, value: 0)
            options: _getEnforcedOptions(130_000)
        });

        // Note: calling SUSDS_OFT.setEnforcedOptions with config created above
        // SUSDS_OFT being 0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1 from chainlog
        SkyOFTAdapterLike(SUSDS_OFT).setEnforcedOptions(susdOftEnforcedOptions);

        // ---------- Monthly Settlement Cycle for March ----------
        // Forum: https://forum.skyeco.com/t/msc-7-settlement-summary-march-2026/27844
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 7,662,339 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 7_662_339 * WAD);

        // Send 1,725,726 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 1_725_726 * WAD);

        // Mint 6,290,684 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_290_684 * WAD);

        // Send 138,412 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 138_412 * WAD);

        // Send 30,241 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 30_241 * WAD);

        // Mint 2,075,648 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 2_075_648 * WAD);

        // Send 69,793 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 69_793 * WAD);

        // Send 225,299 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 225_299 * WAD);

        // Transfer 678,176 USDS from the Surplus Buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 678_176 * WAD);

        // Transfer 33,908 USDS from the Surplus Buffer to the Aligned Delegates Buffer (0x37FC5d447c8c54326C62b697f674c93eaD2A93A3)
        _transferUsds(CORE_COUNCIL_DELEGATE_MULTISIG, 33_908 * WAD);

        // ---------- Staking Rewards Update ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/14
        // Atlas: https://sky-atlas.io/#7da0cd7a-238f-400f-89a7-a419ed25ce37

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 53,960,949 SKY
            vestTot: 192_110_322 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- ALLOCATOR-BLOOM-A DC-IAM Parameter Update ----------
        // Forum: https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase ALLOCATOR-BLOOM-A gap by 250 million USDS from 250 million USDS to 500 million USDS
        // Leave other parameters at current values (line 5 billion USDS, ttl 24 hours)
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-BLOOM-A",
            _gap: 500 * MILLION,
            _amount: 5_000 * MILLION,
            _ttl: 24 hours
        });

        // ---------- ALLOCATOR-PATTERN-A DC-IAM Parameters Update ----------
        // Forum: https://forum.skyeco.com/t/sky-core-increase-allocator-pattern-a-parameters/27842
        // Atlas: https://sky-atlas.io/#41a1ae38-4f5c-468f-b6ba-47e16ecc5aec

        // Increase ALLOCATOR-PATTERN-A gap by 40 million USDS from 10 million USDS to 50 million USDS
        // Increase ALLOCATOR-PATTERN-A line by 2.49 billion USDS from 10 million USDS to 2.5 billion USDS
        // Leave ttl at current value (24 hours)
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PATTERN-A",
            _gap: 50 * MILLION,
            _amount: 2_500 * MILLION,
            _ttl: 24 hours
        });

        // ---------- Whitelist Pattern ALMProxy on the LitePSM ----------
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: https://vote.sky.money/polling/QmVAKhR6

        // Whitelist Pattern ALMProxy at 0xbA43325E91C79E500486a23E953ab3d8C46f169F on the LitePSM
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(PATTERN_ALM_PROXY);

        // ---------- Safe Harbor Update ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-spark-for-upcoming-spell/27831
        // Atlas: https://sky-atlas.io/#6029a425-ad81-46c5-866d-94e2ff663873
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Atlas: https://sky-atlas.io/#b69158da-476a-4d4b-b7ef-2f8b96b73d23

        // Whitelist Spark spell with address 0x160158d029697FEa486dF8968f3Be17a706dF0F0 and codehash 0x96a0d4068774d80f3790f489aa1bbd37e45d6a019161743ad00eaf61e26466b6 in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829
        // Poll: https://vote.sky.money/polling/QmVAKhR6

        // Whitelist Grove spell with address 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929 and codehash 0x43fa1611223445715e33c2ad7baf836cb4c8a00a0ede6fff428b742baefa12c6 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Pattern Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: https://vote.sky.money/polling/QmVAKhR6

        // Whitelist Pattern spell with address 0x31831ae3c13f72afcccf0aaf49b6f9319ed9c4c0 and codehash 0x1478866625ae91e3ca50fa4ff871f5721862e24b9428f15f49b093cc3305587b in PATTERN_STARGUARD, direct execution: No
        StarGuardLike(PATTERN_STARGUARD).plot(PATTERN_SPELL, PATTERN_SPELL_HASH);
    }

    // ---------- Helper Functions ----------

    /// @notice encodes enforced options for OFT, it always uses value as 0
    /// @param gas The gas value for the option
    /// @return enforcedOptions The encoded enforced options
    function _getEnforcedOptions(uint128 gas) internal pure returns(bytes memory enforcedOptions) {
        // Note: 16 bytes (uint128 gas) + 1 bytes (uint8 LZ_OPTION_TYPE_LZRECEIVE) = 17 bytes
        uint16 optionLength = 17;

        // Note: equivalent to OptionsBuilder.addExecutorLzReceiveOption(gas: gas, value: 0)
        // Note: https://github.com/LayerZero-Labs/LayerZero-v2/blob/9c741e7f9790639537b1710a203bcdfd73b0b9ac/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol#L53
        enforcedOptions = abi.encodePacked(
            LZ_OPTIONS_TYPE_3, LZ_EXECUTOR_WORKER_ID, optionLength, LZ_OPTION_TYPE_LZRECEIVE, gas
        );
    }

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

    /// @notice Wraps the operations required to take a payment from a Prime agent
    /// @dev This function effectively increases the debt of the associated Allocator Vault,
    ///      regardless if there is enough room in its debt ceiling.
    /// @param vault The address of the allocator vault
    /// @param wad The amount in wad precision (10 ** 18)
    function _takeAllocatorPayment(address vault, uint256 wad) internal {
        require(wad > 0, "takeAllocatorPayment/zero-amount");
        bytes32 ilk = AllocatorVaultLike(vault).ilk();
        uint256 rate = JugAbstract(MCD_JUG).drip(ilk);
        require(rate > 0, "takeAllocatorPayment/jug-ilk-not-initialized");
        // Note: divup - rounds up in favor of Core.
        uint256 dart = ((wad * RAY - 1) / rate) + 1;
        require(dart <= uint256(type(int256).max), "takeAllocatorPayment/dart-too-large");
        // Note: Take the amount needed, but keep it in the Vow.
        //       This basically generates both sin[vow] and dai[vow] at the same time.
        VatAbstract(MCD_VAT).suck(MCD_VOW, MCD_VOW, dart * rate);
        // Note: Increase the outstanding debt of the vault, while reducing sin[vow], canceling out the sin generated by vat.suck.
        //       The net effect is that dai[vow] and urn[vault].art increase.
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }

}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
