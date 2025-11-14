// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface NttManagerLike {
    function token() external view returns (address);
    function mode() external view returns (uint8);
    function chainId() external view returns (uint16);
    function rateLimitDuration() external view returns (uint64);
    function upgrade(address) external;
    function migrateLockedTokens(address) external;
}

interface WormholeLike {
    function messageFee() external view returns (uint256);
    function publishMessage(uint32 nonce, bytes memory payload, uint8 consistencyLevel) external payable returns (uint64);
}

interface OAppLike {
    function owner() external view returns (address);
    function endpoint() external view returns (address);
    function peers(uint32) external view returns (bytes32);
}

interface OFTAdapterLike is OAppLike {
    struct RateLimitConfig {
        uint32 eid;
        uint48 window;
        uint256 limit;
    }
    function token() external view returns (address);
    function defaultFeeBps() external view returns (uint16);
    function feeBps(uint32) external view returns (uint16, bool);
    function paused() external view returns (bool);
    function outboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
    function inboundRateLimits(uint32) external view returns (uint128, uint48, uint256, uint256);
    function rateLimitAccountingType() external view returns (uint8);
    function setRateLimits(RateLimitConfig[] calldata, RateLimitConfig[] calldata) external;
}

interface EndpointLike {
    function delegates(address) external view returns (address);
}

library MigrationInit {
    ChainlogLike constant LOG = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    address constant WORMHOLE_CORE_BRIDGE = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;
    address constant NTT_MANAGER          = 0x7d4958454a3f520bDA8be764d06591B054B0bf33;
    address constant ETH_LZ_ENDPOINT      = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32  constant SOL_EID              = 30168;

    function _publishWHMessage(address wormhole, uint256 fee, bytes memory payload) internal {
        WormholeLike(wormhole).publishMessage{value: fee}({
            nonce: 0,
            payload: payload,
            consistencyLevel: 202 // "Finalized" (~19 minutes - see https://wormhole.com/docs/build/reference/consistency-levels/)
        });
    }

    //////////////////////
    /////// Step 0 ///////
    //////////////////////

    function initMigrationStep0(
        address nttManagerImpV2,
        uint256 maxFee,
        bytes memory payload,
        address nttManager,
        address wormhole
    ) internal {
        NttManagerLike mgr   = NttManagerLike(nttManager);
        NttManagerLike impV2 = NttManagerLike(nttManagerImpV2);

        // Sanity checks
        require(impV2.token()             == mgr.token(),             "MigrationInit/token-mismatch");
        require(impV2.mode()              == mgr.mode(),              "MigrationInit/mode-mismatch");
        require(impV2.chainId()           == mgr.chainId(),           "MigrationInit/chain-id-mismatch");
        require(impV2.rateLimitDuration() == mgr.rateLimitDuration(), "MigrationInit/rl-dur-mismatch");
        
        // Upgrade Ethereum NTT Manager
        mgr.upgrade(nttManagerImpV2);

        // Upgrade Solana NTT Manager
        uint256 fee = WormholeLike(wormhole).messageFee();
        require(fee <= maxFee, "MigrationInit/exceeds-max-fee");
        _publishWHMessage({
            wormhole: wormhole,
            fee:      fee,
            payload:  payload
        });
    }

    function initMigrationStep0(
        address nttManagerImpV2,
        uint256 maxFee,
        bytes memory payload
    ) internal {
        initMigrationStep0({
            nttManagerImpV2: nttManagerImpV2,
            maxFee:          maxFee,
            payload:         payload,
            nttManager:      NTT_MANAGER,
            wormhole:        WORMHOLE_CORE_BRIDGE
        });
    }

    //////////////////////
    /////// Step 1 ///////
    //////////////////////

    function _sanityCheckOapp(address oapp, uint32 solEid, address owner, address endpoint, bytes32 peer) internal view {
        OAppLike oapp_ = OAppLike(oapp);
        // Note that the oapp's enforcedOptions are assumed to have been manually reviewed by Sky
        require(oapp_.owner() == owner,                          "MigrationInit/owner-mismatch");
        require(oapp_.endpoint() == endpoint,                    "MigrationInit/endpoint-mismatch");
        require(oapp_.peers(solEid) == peer,                     "MigrationInit/peer-mismatch");
        require(EndpointLike(endpoint).delegates(oapp) == owner, "MigrationInit/delegate-mismatch");
    }

    function _sanityCheckOft(address oftAdapter, uint32 solEid, address token, uint8 rlAccountingType) internal view {
        OFTAdapterLike oft = OFTAdapterLike(oftAdapter);
        (uint16 feeBps, bool enabled) = oft.feeBps(solEid);
        (,,,uint256 outLimit) = oft.outboundRateLimits(solEid);
        (,,,uint256  inLimit) = oft.inboundRateLimits(solEid);
        require(oft.token() == token,                               "MigrationInit/token-mismatch");
        require(oft.defaultFeeBps() == 0,                           "MigrationInit/incorrect-default-fee");
        require(feeBps == 0 && !enabled,                            "MigrationInit/incorrect-solana-fee");
        require(!oft.paused(),                                      "MigrationInit/paused");
        require(outLimit == 0,                                      "MigrationInit/outbound-rl-nonzero");
        require(inLimit  == 0,                                      "MigrationInit/inbound-rl-nonzero");
        require(oft.rateLimitAccountingType() == rlAccountingType , "MigrationInit/rl-accounting-mismatch");
    }

    struct RateLimitsParams {
        uint48  outboundWindow;
        uint256 outboundLimit;
        uint48  inboundWindow;
        uint256 inboundLimit;
        uint8   rlAccountingType;
    }

    struct MigrationStep1Params {
        address oftAdapter;
        bytes32 oftPeer;
        address govOapp; 
        bytes32 govPeer;
        RateLimitsParams rl;
        uint256 maxFee;
        bytes transferMintAuthPayload;
        bytes transferFreezeAuthPayload;
        bytes transferMetadataUpdateAuthPayload;
        address nttManager;
        address wormhole;
        address owner;
        address endpoint;
        uint32  solEid;
    }

    function initMigrationStep1(
        MigrationStep1Params memory p
    ) internal {
        // Sanity checks
        _sanityCheckOapp(p.oftAdapter, p.solEid, p.owner, p.endpoint, p.oftPeer);
        _sanityCheckOapp(p.govOapp,    p.solEid, p.owner, p.endpoint, p.govPeer);
        _sanityCheckOft(p.oftAdapter, p.solEid, NttManagerLike(p.nttManager).token(), p.rl.rlAccountingType);

        // Migrated Locked Tokens
        NttManagerLike(p.nttManager).migrateLockedTokens(p.oftAdapter);

        // Activate USDS Ethereum LZ Bridge
        OFTAdapterLike.RateLimitConfig[] memory inboundCfg  = new OFTAdapterLike.RateLimitConfig[](1);
        OFTAdapterLike.RateLimitConfig[] memory outboundCfg = new OFTAdapterLike.RateLimitConfig[](1);
        inboundCfg[0]  = OFTAdapterLike.RateLimitConfig(p.solEid, p.rl.inboundWindow,  p.rl.inboundLimit);
        outboundCfg[0] = OFTAdapterLike.RateLimitConfig(p.solEid, p.rl.outboundWindow, p.rl.outboundLimit);
        OFTAdapterLike(p.oftAdapter).setRateLimits(inboundCfg, outboundCfg);
        
        uint256 fee = WormholeLike(p.wormhole).messageFee();
        require(fee <= p.maxFee, "MigrationInit/exceeds-max-fee");

        // Transfer Mint Authority
        _publishWHMessage({
            wormhole: p.wormhole,
            fee:      fee,
            payload:  p.transferMintAuthPayload
        });

        // Transfer Freeze Authority
        _publishWHMessage({
            wormhole: p.wormhole,
            fee:      fee,
            payload:  p.transferFreezeAuthPayload
        });

        // Transfer Metadata Update Authority
        _publishWHMessage({
            wormhole: p.wormhole,
            fee:      fee,
            payload:  p.transferMetadataUpdateAuthPayload
        });
    }

    function initMigrationStep1(
        address oftAdapter,
        bytes32 oftPeer,
        address govOapp,
        bytes32 govPeer,
        RateLimitsParams memory rl,
        uint256 maxFee,
        bytes memory transferMintAuthPayload,
        bytes memory transferFreezeAuthPayload,
        bytes memory transferMetadataUpdateAuthPayload
    ) internal {
        MigrationStep1Params memory p = MigrationStep1Params({
            oftAdapter:                        oftAdapter,
            oftPeer:                           oftPeer,
            govOapp:                           govOapp,
            govPeer:                           govPeer,
            rl:                                rl,
            maxFee:                            maxFee,
            transferMintAuthPayload:           transferMintAuthPayload,
            transferFreezeAuthPayload:         transferFreezeAuthPayload,
            transferMetadataUpdateAuthPayload: transferMetadataUpdateAuthPayload,
            nttManager:                        NTT_MANAGER,
            wormhole:                          WORMHOLE_CORE_BRIDGE,
            owner:                             LOG.getAddress("MCD_PAUSE_PROXY"),
            endpoint:                          ETH_LZ_ENDPOINT,
            solEid:                            SOL_EID
        });
        initMigrationStep1(p);
    }

    function initSusdsBridge(
        address oftAdapter,
        bytes32 oftPeer,
        RateLimitsParams memory rl
    ) internal {
        // Sanity checks
        _sanityCheckOapp(oftAdapter, SOL_EID, LOG.getAddress("MCD_PAUSE_PROXY"), ETH_LZ_ENDPOINT, oftPeer);
        _sanityCheckOft(oftAdapter, SOL_EID, LOG.getAddress("SUSDS"), rl.rlAccountingType);

        // Activate sUSDS Ethereum LZ Bridge
        OFTAdapterLike.RateLimitConfig[] memory inboundCfg  = new OFTAdapterLike.RateLimitConfig[](1);
        OFTAdapterLike.RateLimitConfig[] memory outboundCfg = new OFTAdapterLike.RateLimitConfig[](1);
        inboundCfg[0]  = OFTAdapterLike.RateLimitConfig(SOL_EID, rl.inboundWindow,  rl.inboundLimit);
        outboundCfg[0] = OFTAdapterLike.RateLimitConfig(SOL_EID, rl.outboundWindow, rl.outboundLimit);
        OFTAdapterLike(oftAdapter).setRateLimits(inboundCfg, outboundCfg);
    }
}
