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

import "./DssSpell.t.base.sol";
import {ScriptTools} from "dss-test/DssTest.sol";

interface L2Spell {
    function dstDomain() external returns (bytes32);
    function gateway() external returns (address);
}

interface L2Gateway {
    function validDomains(bytes32) external returns (uint256);
}

interface BridgeLike {
    function l2TeleportGateway() external view returns (address);
}

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface SpellActionLike {
    function dao_resolutions() external view returns (string memory);
}

interface SequencerLike {
    function hasJob(address job) external view returns (bool);
    function getMaster() external view returns (bytes32);
}

interface L1GovernanceRelayLike {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct TxParams {
        uint32 dstEid;
        bytes32 dstTarget;
        bytes dstCallData;
        bytes extraOptions;
    }

    function l1Oapp() external view returns (address);
    function relayEVM(
        uint32                dstEid,
        address               l2GovernanceRelay,
        address               target,
        bytes calldata        targetData,
        bytes calldata        extraOptions,
        MessagingFee calldata fee,
        address               refundAddress
    ) external payable;
    function relayRaw(
        TxParams calldata     txParams,
        MessagingFee calldata fee,
        address               refundAddress
    ) external payable;
}

interface WormholeLike {
    function nextSequence(address emitter) external view returns (uint64);
}

interface OAppLike {
    function setPeer(uint32 _eid, bytes32 _peer) external;
}

interface GovernanceOAppSenderLike is OAppLike {
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
}

interface SkyOFTAdapterLike is OAppLike {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    function inboundRateLimits(uint32 srcEid)
        external
        view
        returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
    function outboundRateLimits(uint32 dstEid)
        external
        view
        returns (uint128 lastUpdated, uint48 window, uint256 amountInFlight, uint256 limit);
    function pause() external;
    function paused() external view returns (bool);
    function pausers(address pauser) external view returns (bool canPause);
    function quoteSend(SendParam memory _sendParam, bool _payInLzToken)
        external
        view
        returns (MessagingFee memory msgFee);
    function send(SendParam memory _sendParam, MessagingFee memory _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);
    function unpause() external;
}

contract DssSpellTest is DssSpellTestBase {
    using stdStorage for StdStorage;

    // DO NOT TOUCH THE FOLLOWING TESTS, THEY SHOULD BE RUN ON EVERY SPELL
    function testGeneral() public {
        _testGeneral();
    }

    function testOfficeHours() public {
        _testOfficeHours();
    }

    function testCastOnTime() public {
        _testCastOnTime();
    }

    function testNextCastTime() public {
        _testNextCastTime();
    }

    function testRevertIfNotScheduled() public {
        _testRevertIfNotScheduled();
    }

    function testUseEta() public {
        _testUseEta();
    }

    function testContractSize() public skippedWhenDeployed {
        _testContractSize();
    }

    function testDeployCost() public skippedWhenDeployed {
        _testDeployCost();
    }

    function testBytecodeMatches() public skippedWhenNotDeployed {
        _testBytecodeMatches();
    }

    function testCastCost() public {
        _testCastCost();
    }

    function testChainlogIntegrity() public {
        _testChainlogIntegrity();
    }

    function testChainlogValues() public {
        _testChainlogValues();
    }

    function testSplitter() public {
        _testSplitter();
    }

    function testSystemTokens() public {
        _testSystemTokens();
    }

    function testSPBEAMTauAndBudValues() public {
        _testSPBEAMTauAndBudValues();
    }

    // Leave this test always enabled as it acts as a config test
    function testPSMs() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        bytes32 _ilk;

        // USDC
        _ilk = "PSM-USDC-A";
        assertEq(addr.addr("MCD_JOIN_PSM_USDC_A"), reg.join(_ilk));
        assertEq(addr.addr("MCD_CLIP_PSM_USDC_A"), reg.xlip(_ilk));
        assertEq(addr.addr("PIP_USDC"), reg.pip(_ilk));
        assertEq(addr.addr("MCD_PSM_USDC_A"), chainLog.getAddress("MCD_PSM_USDC_A"));
        _checkPsmIlkIntegration(
            _ilk,
            GemJoinAbstract(addr.addr("MCD_JOIN_PSM_USDC_A")),
            ClipAbstract(addr.addr("MCD_CLIP_PSM_USDC_A")),
            addr.addr("PIP_USDC"),
            PsmAbstract(addr.addr("MCD_PSM_USDC_A")),
            0,   // tin
            0    // tout
        );

        // GUSD
        _ilk = "PSM-GUSD-A";
        assertEq(addr.addr("MCD_JOIN_PSM_GUSD_A"), reg.join(_ilk));
        assertEq(addr.addr("MCD_CLIP_PSM_GUSD_A"), reg.xlip(_ilk));
        assertEq(addr.addr("PIP_GUSD"), reg.pip(_ilk));
        assertEq(addr.addr("MCD_PSM_GUSD_A"), chainLog.getAddress("MCD_PSM_GUSD_A"));
        _checkPsmIlkIntegration(
            _ilk,
            GemJoinAbstract(addr.addr("MCD_JOIN_PSM_GUSD_A")),
            ClipAbstract(addr.addr("MCD_CLIP_PSM_GUSD_A")),
            addr.addr("PIP_GUSD"),
            PsmAbstract(addr.addr("MCD_PSM_GUSD_A")),
            0,  // tin
            0    // tout
        );

        // USDP
        _ilk = "PSM-PAX-A";
        assertEq(addr.addr("MCD_JOIN_PSM_PAX_A"), reg.join(_ilk));
        assertEq(addr.addr("MCD_CLIP_PSM_PAX_A"), reg.xlip(_ilk));
        assertEq(addr.addr("PIP_PAX"), reg.pip(_ilk));
        assertEq(addr.addr("MCD_PSM_PAX_A"), chainLog.getAddress("MCD_PSM_PAX_A"));
        _checkPsmIlkIntegration(
            _ilk,
            GemJoinAbstract(addr.addr("MCD_JOIN_PSM_PAX_A")),
            ClipAbstract(addr.addr("MCD_CLIP_PSM_PAX_A")),
            addr.addr("PIP_PAX"),
            PsmAbstract(addr.addr("MCD_PSM_PAX_A")),
            0,   // tin
            0    // tout
        );
    }

    // Leave this test always enabled as it acts as a config test
    function testLitePSMs() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        bytes32 _ilk;

        // USDC
        _ilk = "LITE-PSM-USDC-A";
        assertEq(addr.addr("PIP_USDC"),            reg.pip(_ilk));
        assertEq(addr.addr("MCD_LITE_PSM_USDC_A"), chainLog.getAddress("MCD_LITE_PSM_USDC_A"));
        _checkLitePsmIlkIntegration(
            LitePsmIlkIntegrationParams({
                ilk:      _ilk,
                pip:      addr.addr("PIP_USDC"),
                litePsm:  addr.addr("MCD_LITE_PSM_USDC_A"),
                pocket:   addr.addr("MCD_LITE_PSM_USDC_A_POCKET"),
                bufUnits: 400_000_000,
                tinBps:             0,
                toutBps:            0
            })
        );
    }

    // END OF TESTS THAT SHOULD BE RUN ON EVERY SPELL

    // TESTS BELOW CAN BE ENABLED/DISABLED ON DEMAND

    function testOracleList() public skipped { // TODO: check if this test can be removed for good.
        // address ORACLE_WALLET01 = 0x4D6fbF888c374D7964D56144dE0C0cFBd49750D3;

        //assertEq(OsmAbstract(0xF15993A5C5BE496b8e1c9657Fd2233b579Cd3Bc6).wards(ORACLE_WALLET01), 0);

        //_vote(address(spell));
        //_scheduleWaitAndCast(address(spell));
        //assertTrue(spell.done());

        //assertEq(OsmAbstract(0xF15993A5C5BE496b8e1c9657Fd2233b579Cd3Bc6).wards(ORACLE_WALLET01), 1);
    }

    function testRemovedChainlogKeys() public skipped { // add the `skipped` modifier to skip
        string[43] memory removedKeys = [
            "PIP_MKR",
            "PIP_AAVE",
            "PIP_ADAI",
            "PIP_BAL",
            "PIP_BAT",
            "PIP_COMP",
            "PIP_CRVV1ETHSTETH",
            "PIP_GNO",
            "PIP_GUSD",
            "PIP_KNC",
            "PIP_LINK",
            "PIP_LRC",
            "PIP_MANA",
            "PIP_MATIC",
            "PIP_PAX",
            "PIP_PAXUSD",
            "PIP_RENBTC",
            "PIP_RETH",
            "PIP_RWA003",
            "PIP_RWA006",
            "PIP_RWA007",
            "PIP_RWA008",
            "PIP_RWA010",
            "PIP_RWA011",
            "PIP_RWA012",
            "PIP_RWA013",
            "PIP_RWA014",
            "PIP_RWA015",
            "PIP_TUSD",
            "PIP_UNI",
            "PIP_UNIV2AAVEETH",
            "PIP_UNIV2DAIETH",
            "PIP_UNIV2DAIUSDT",
            "PIP_UNIV2ETHUSDT",
            "PIP_UNIV2LINKETH",
            "PIP_UNIV2UNIETH",
            "PIP_UNIV2USDCETH",
            "PIP_UNIV2WBTCDAI",
            "PIP_UNIV2WBTCETH",
            "PIP_USDC",
            "PIP_USDT",
            "PIP_YFI",
            "PIP_ZRX"
        ];

        for (uint256 i = 0; i < removedKeys.length; i++) {
            try chainLog.getAddress(_stringToBytes32(removedKeys[i])) {
            } catch Error(string memory errmsg) {
                if (_cmpStr(errmsg, "dss-chain-log/invalid-key")) {
                    revert(_concat("TestError/key-to-remove-does-not-exist: ", removedKeys[i]));
                } else {
                    revert(errmsg);
                }
            }
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < removedKeys.length; i++) {
            try chainLog.getAddress(_stringToBytes32(removedKeys[i])) {
                revert(_concat("TestError/key-not-removed: ", removedKeys[i]));
            } catch Error(string memory errmsg) {
                assertTrue(
                    _cmpStr(errmsg, "dss-chain-log/invalid-key"),
                    _concat("TestError/key-not-removed: ", removedKeys[i])
                );
            } catch {
                revert(_concat("TestError/unknown-reason: ", removedKeys[i]));
            }
        }
    }

    function testAddedChainlogKeys() public { // add the `skipped` modifier to skip
        string[3] memory addedKeys = [
            "USDS_OFT",
            "LZ_GOV_SENDER",
            "LZ_GOV_RELAY"
        ];

        for(uint256 i = 0; i < addedKeys.length; i++) {
            vm.expectRevert("dss-chain-log/invalid-key");
            chainLog.getAddress(_stringToBytes32(addedKeys[i]));
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for(uint256 i = 0; i < addedKeys.length; i++) {
            assertEq(
                chainLog.getAddress(_stringToBytes32(addedKeys[i])),
                addr.addr(_stringToBytes32(addedKeys[i])),
                string.concat(_concat("testNewChainlogKeys/chainlog-key-mismatch: ", addedKeys[i]))
            );
        }
    }

    function testCollateralIntegrations() public skipped { // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Insert new collateral tests here
        _checkIlkIntegration(
            "GNO-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_GNO_A")),
            ClipAbstract(addr.addr("MCD_CLIP_GNO_A")),
            addr.addr("PIP_GNO"),
            true, /* _isOSM */
            true, /* _checkLiquidations */
            false /* _transferFee */
        );
    }

    function testIlkClipper() public skipped {  // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

       _checkIlkClipper(
            "UNIV2DAIUSDC-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_UNIV2DAIUSDC_A")),
            ClipAbstract(addr.addr("MCD_CLIP_UNIV2DAIUSDC_A")),
            addr.addr("MCD_CLIP_CALC_UNIV2DAIUSDC_A"),
            OsmAbstract(addr.addr("PIP_UNIV2DAIUSDC")),
            1 * WAD
        );
    }

    function testLockstakeIlkIntegration() public skipped { // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        _checkLockstakeIlkIntegration(
            LockstakeIlkParams({
                ilk:    "LSEV2-SKY-A",
                fee:    0,
                pip:    addr.addr("LOCKSTAKE_ORACLE"),
                lssky:  addr.addr("LOCKSTAKE_SKY"),
                engine: addr.addr("LOCKSTAKE_ENGINE"),
                clip:   addr.addr("LOCKSTAKE_CLIP"),
                calc:   addr.addr("LOCKSTAKE_CLIP_CALC"),
                farm:   addr.addr("REWARDS_LSSKY_SKY"),
                rToken: addr.addr("SKY"),
                rDistr: addr.addr("REWARDS_DIST_LSSKY_SKY"),
                rDur:   7 days
            })
        );
    }

    function testAllocatorIntegration() public skipped { // add the `skipped` modifier to skip
        AllocatorIntegrationParams memory p = AllocatorIntegrationParams({
            ilk:            "ALLOCATOR-OBEX-A",
            pip:            addr.addr("PIP_ALLOCATOR"),
            registry:       addr.addr("ALLOCATOR_REGISTRY"),
            roles:          addr.addr("ALLOCATOR_ROLES"),
            buffer:         addr.addr("ALLOCATOR_OBEX_A_BUFFER"),
            vault:          addr.addr("ALLOCATOR_OBEX_A_VAULT"),
            allocatorProxy: addr.addr("ALLOCATOR_OBEX_A_SUBPROXY"),
            owner:          addr.addr("MCD_PAUSE_PROXY")
        });

        // Sanity checks
        require(AllocatorVaultLike(p.vault).ilk()      == p.ilk,                 "AllocatorInit/vault-ilk-mismatch");
        require(AllocatorVaultLike(p.vault).roles()    == p.roles,               "AllocatorInit/vault-roles-mismatch");
        require(AllocatorVaultLike(p.vault).buffer()   == p.buffer,              "AllocatorInit/vault-buffer-mismatch");
        require(AllocatorVaultLike(p.vault).vat()      == address(vat),          "AllocatorInit/vault-vat-mismatch");
        require(AllocatorVaultLike(p.vault).usdsJoin() == address(usdsJoin),     "AllocatorInit/vault-usds-join-mismatch");
        require(AllocatorVaultLike(p.vault).wards(p.owner) == 1, "TestError/vault-owner-not-authed");
        require(WardsAbstract(p.buffer).wards(p.owner) == 1, "TestError/buffer-owner-not-authed");

        if (p.owner != p.allocatorProxy) {
            require(AllocatorVaultLike(p.vault).wards(p.allocatorProxy) == 0, "TestError/vault-allocator-proxy-authed-early");
            require(WardsAbstract(p.buffer).wards(p.allocatorProxy) == 0, "TestError/buffer-allocator-proxy-authed-early");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        _checkAllocatorIntegration(p);

        // Note: skipped for this onboarding as no operators are added
        // Role and allowance checks - Specific to ALLOCATOR-BLOOM-A only
        // address allocatorOperator = wallets.addr("BLOOM_OPERATOR");
        // assertEq(usds.allowance(p.buffer, allocatorOperator), type(uint256).max);
        // assertTrue(AllocatorRolesLike(p.roles).hasActionRole("ALLOCATOR-BLOOM-A", p.vault, AllocatorVaultLike.draw.selector, 0));
        // assertTrue(AllocatorRolesLike(p.roles).hasActionRole("ALLOCATOR-BLOOM-A", p.vault, AllocatorVaultLike.wipe.selector, 0));

        // The allocator proxy should be able to call draw() wipe()
        vm.prank(p.allocatorProxy);
        AllocatorVaultLike(p.vault).draw(1_000 * WAD);
        assertEq(usds.balanceOf(p.buffer), 1_000 * WAD);

        vm.warp(block.timestamp + 1);
        jug.drip(p.ilk);

        vm.prank(p.allocatorProxy);
        AllocatorVaultLike(p.vault).wipe(1_000 * WAD);
        assertEq(usds.balanceOf(p.buffer), 0);
    }

    function testLerpSurplusBuffer() public skipped { // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Insert new SB lerp tests here

        LerpAbstract lerp = LerpAbstract(lerpFactory.lerps("NAME"));

        uint256 duration = 210 days;
        vm.warp(block.timestamp + duration / 2);
        assertEq(vow.hump(), 60 * MILLION * RAD);
        lerp.tick();
        assertEq(vow.hump(), 75 * MILLION * RAD);
        vm.warp(block.timestamp + duration / 2);
        lerp.tick();
        assertEq(vow.hump(), 90 * MILLION * RAD);
        assertTrue(lerp.done());
    }

    function testEsmAuth() public skipped { // add the `skipped` modifier to skip
        string[1] memory esmAuthorisedContractKeys = [
            "MCD_LITE_PSM_USDC_A_IN_CDT_JAR"
        ];

        for (uint256 i = 0; i < esmAuthorisedContractKeys.length; i++) {
            assertEq(
                WardsAbstract(addr.addr(_stringToBytes32(esmAuthorisedContractKeys[i]))).wards(address(esm)),
                0,
                _concat("TestError/esm-is-ward-before-spell: ", esmAuthorisedContractKeys[i])
            );
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < esmAuthorisedContractKeys.length; i++) {
            assertEq(
                WardsAbstract(addr.addr(_stringToBytes32(esmAuthorisedContractKeys[i]))).wards(address(esm)),
                1,
                _concat("TestError/esm-is-not-ward-after-spell: ", esmAuthorisedContractKeys[i])
            );
        }
    }

    function testOsmReaders() public skipped { // add the `skipped` modifier to skip
        address OSM = addr.addr("PIP_SKY");
        address[4] memory newReaders = [
            addr.addr("MCD_SPOT"),
            addr.addr("LOCKSTAKE_CLIP"),
            addr.addr("CLIPPER_MOM"),
            addr.addr("MCD_END")
        ];

        for (uint256 i = 0; i < newReaders.length; i++) {
            assertEq(OsmAbstract(OSM).bud(newReaders[i]), 0);
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < newReaders.length; i++) {
            assertEq(OsmAbstract(OSM).bud(newReaders[i]), 1);
        }
    }

    function testMedianReaders() public skipped { // add the `skipped` modifier to skip
        address median = chainLog.getAddress("PIP_MKR"); // PIP_MKR before spell
        address[1] memory newReaders = [
            addr.addr('PIP_MKR') // PIP_MKR after spell
        ];

        for (uint256 i = 0; i < newReaders.length; i++) {
            assertEq(MedianAbstract(median).bud(newReaders[i]), 0);
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < newReaders.length; i++) {
            assertEq(MedianAbstract(median).bud(newReaders[i]), 1);
        }
    }

    struct Authorization {
        bytes32 base;
        bytes32 ward;
    }

    function testNewAuthorizations() public skipped { // add the `skipped` modifier to skip
        Authorization[5] memory newAuthorizations = [
            Authorization({ base: "MCD_VAT", ward: "STUSDS" }),
            Authorization({ base: "STUSDS", ward: "STUSDS_MOM" }),
            Authorization({ base: "STUSDS_RATE_SETTER", ward: "STUSDS_MOM" }),
            Authorization({ base: "STUSDS", ward: "STUSDS_RATE_SETTER" }),
            Authorization({ base: "STUSDS", ward: "LOCKSTAKE_CLIP" })
        ];

        for (uint256 i = 0; i < newAuthorizations.length; i++) {
            address base = addr.addr(newAuthorizations[i].base);
            address ward = addr.addr(newAuthorizations[i].ward);
            assertEq(WardsAbstract(base).wards(ward), 0, _concat("testNewAuthorizations/already-authorized-", newAuthorizations[i].base));
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < newAuthorizations.length; i++) {
            address base = addr.addr(newAuthorizations[i].base);
            address ward = addr.addr(newAuthorizations[i].ward);
            assertEq(WardsAbstract(base).wards(ward), 1, _concat("testNewAuthorizations/not-authorized-", newAuthorizations[i].base));
        }
    }

    function testVestDai() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 OCT_01_2024 = 1727740800;
        uint256 JAN_31_2025 = 1738367999;

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  39,
            usr: wallets.addr("JANSKY"),
            bgn: OCT_01_2024,
            clf: OCT_01_2024,
            fin: JAN_31_2025,
            tau: 123 days - 1,
            mgr: address(0),
            res: 1,
            tot: 168_000 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestDai, gem: GemAbstract(address(dai)), name: "dai", isTransferrable: false}),
            newStreams,
            yankedStreams
        );
    }

    function testVestMkr() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 OCT_01_2024 = 1727740800;
        uint256 JAN_31_2025 = 1738367999;

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  45,
            usr: wallets.addr("JANSKY"),
            bgn: OCT_01_2024,
            clf: OCT_01_2024,
            fin: JAN_31_2025,
            tau: 123 days - 1,
            mgr: address(0),
            res: 1,
            tot: 72 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestMkr, gem: GemAbstract(address(mkr)), name: "mkr", isTransferrable: true}),
            newStreams,
            yankedStreams
        );
    }

    function testVestUsds() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 FEB_01_2025 = 1738368000;
        uint256 DEC_31_2025 = 1767225599;

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](3);
        newStreams[0] = NewVestStream({
            id:  1,
            usr: wallets.addr("VOTEWIZARD"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0 // Amount already claimed
        });
        newStreams[1] = NewVestStream({
            id:  2,
            usr: wallets.addr("JANSKY"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0 // Amount already claimed
        });
        newStreams[2] = NewVestStream({
            id:  3,
            usr: wallets.addr("ECOSYSTEM_FACILITATOR"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestUsds, gem: usds, name: "usds", isTransferrable: false}),
            newStreams,
            yankedStreams
        );
    }

    function testVestSky() public skipped { // add the `skipped` modifier to skip
        uint256 spellCastTime = _getSpellCastTime();

        // Build expected new stream
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  8,
            usr: addr.addr("REWARDS_DIST_LSSKY_SKY"),
            bgn: spellCastTime - 7 days,
            clf: spellCastTime - 7 days,
            fin: (spellCastTime - 7 days) + 180 days,
            tau: 180 days,
            mgr: address(0),
            res: 1,
            tot: 1_000_000_000 * WAD,
            rxd: (7 days * 1_000_000_000 * WAD) / 180 days
        });

        // No yanked streams expected
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestSky, gem: sky, name: "sky", isTransferrable: true}),
            newStreams,
            yankedStreams
        );
    }

    function testVestSkyMint() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        // uint256 DEC_01_2023 = 1701385200;

        uint256 spellCastTime = _getSpellCastTime();

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  2,
            usr: addr.addr("REWARDS_DIST_USDS_SKY"),
            bgn: spellCastTime,
            clf: spellCastTime,
            fin: spellCastTime + 15_724_800 seconds,
            tau: 15_724_800 seconds,
            mgr: address(0),
            res: 1,
            tot: 160_000_000 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestSkyMint, gem: sky, name: "skyMint", isTransferrable: false}),
            newStreams,
            yankedStreams
        );
    }

    function testVestSpk() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 spellCastTime = _getSpellCastTime();
        uint256 CAST_TIME_MINUS_7_DAYS = spellCastTime - 7 days;
        uint256 BGN_PLUS_730_DAYS = CAST_TIME_MINUS_7_DAYS + 730 days;

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](2);

        newStreams[0] = NewVestStream({
            id:  1,
            usr: addr.addr("REWARDS_DIST_USDS_SPK"),
            bgn: CAST_TIME_MINUS_7_DAYS,
            clf: CAST_TIME_MINUS_7_DAYS,
            fin: BGN_PLUS_730_DAYS,
            tau: 730 days,
            mgr: address(0),
            res: 1,
            tot: 2_275_000_000 * WAD,
            rxd: 7 days * 2_275_000_000 * WAD / 730 days  // Amount already claimed
        });
        newStreams[1] = NewVestStream({
            id:  2,
            usr: addr.addr("REWARDS_DIST_LSSKY_SPK"),
            bgn: CAST_TIME_MINUS_7_DAYS,
            clf: CAST_TIME_MINUS_7_DAYS,
            fin: BGN_PLUS_730_DAYS,
            tau: 730 days,
            mgr: address(0),
            res: 1,
            tot: 975_000_000 * WAD,
            rxd: 7 days * 975_000_000 * WAD / 730 days  // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestSpk, gem: spk, name: "spk", isTransferrable: true}),
            newStreams,
            yankedStreams
        );
    }

    struct Payee {
        address token;
        address addr;
        int256 amount;
    }

    struct PaymentAmounts {
        int256 dai;
        int256 mkr;
        int256 usds;
        int256 sky;
    }

    struct TreasuryAmounts {
        int256 mkr;
        int256 sky;
    }

    function testPayments() public skipped { // add the `skipped` modifier to skip
        // Note: set to true when there are additional DAI/USDS operations (e.g. surplus buffer sweeps, SubDAO draw-downs) besides direct transfers
        bool ignoreTotalSupplyDaiUsds = false;
        bool ignoreTotalSupplyMkrSky = true;

        // For each payment, create a Payee object with:
        //    the address of the transferred token,
        //    the destination address,
        //    the amount to be paid
        // Initialize the array with the number of payees
        Payee[3] memory payees = [
            Payee(address(usds), wallets.addr("CORE_COUNCIL_BUDGET_MULTISIG"), 3_876_387 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CORE_COUNCIL_DELEGATE_MULTISIG"), 193_820 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("INTEGRATION_BOOST_INITIATIVE"), 1_000_000 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:                               0 ether, // Note: ether is only a keyword helper
            mkr:                               0 ether, // Note: ether is only a keyword helper
            usds:                      5_070_207 ether, // Note: ether is only a keyword helper
            sky:                               0 ether  // Note: ether is only a keyword helper
        });

        // Fill the total values based on the source for the transfers above
        TreasuryAmounts memory expectedTreasuryBalancesDiff = TreasuryAmounts({
            mkr: 0 ether, // Note: ether is only a keyword helper
            sky: 0 ether  // Note: ether is only a keyword helper
        });

        // Vote, schedule and warp, but not yet cast (to get correct surplus balance)
        _vote(address(spell));
        spell.schedule();
        vm.warp(spell.nextCastTime());
        pot.drip();

        // Calculate and save previous balances
        uint256 previousSurplusBalance = vat.sin(address(vow));
        TreasuryAmounts memory previousTreasuryBalances = TreasuryAmounts({
            mkr: int256(mkr.balanceOf(pauseProxy)),
            sky: int256(sky.balanceOf(pauseProxy))
        });
        PaymentAmounts memory previousTotalSupply = PaymentAmounts({
            dai: int256(dai.totalSupply()),
            mkr: int256(mkr.totalSupply()),
            usds: int256(usds.totalSupply()),
            sky: int256(sky.totalSupply())
        });
        PaymentAmounts memory calculatedTotalPayments;
        PaymentAmounts[] memory previousPayeeBalances = new PaymentAmounts[](payees.length);

        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i].token == address(dai)) {
                calculatedTotalPayments.dai += payees[i].amount;
            } else if (payees[i].token == address(mkr)) {
                calculatedTotalPayments.mkr += payees[i].amount;
            } else if (payees[i].token == address(usds)) {
                calculatedTotalPayments.usds += payees[i].amount;
            } else if (payees[i].token == address(sky)) {
                calculatedTotalPayments.sky += payees[i].amount;
            } else {
                revert('TestPayments/unexpected-payee-token');
            }
            previousPayeeBalances[i] = PaymentAmounts({
                dai: int256(dai.balanceOf(payees[i].addr)),
                mkr: int256(mkr.balanceOf(payees[i].addr)),
                usds: int256(usds.balanceOf(payees[i].addr)),
                sky: int256(sky.balanceOf(payees[i].addr))
            });
        }

        assertEq(
            calculatedTotalPayments.dai,
            expectedTotalPayments.dai,
            "TestPayments/calculated-vs-expected-dai-total-mismatch"
        );
        assertEq(
            calculatedTotalPayments.usds,
            expectedTotalPayments.usds,
            "TestPayments/calculated-vs-expected-usds-total-mismatch"
        );
        assertEq(
            calculatedTotalPayments.mkr,
            expectedTotalPayments.mkr,
            "TestPayments/calculated-vs-expected-mkr-total-mismatch"
        );
        assertEq(
            calculatedTotalPayments.sky,
            expectedTotalPayments.sky,
            "TestPayments/calculated-vs-expected-sky-total-mismatch"
        );

        // Cast spell
        spell.cast();
        assertTrue(spell.done(), "TestPayments/spell-not-done");

        // Check calculated vs actual totals
        PaymentAmounts memory totalSupplyDiff = PaymentAmounts({
            dai:  int256(dai.totalSupply())  - previousTotalSupply.dai,
            mkr:  int256(mkr.totalSupply())  - previousTotalSupply.mkr,
            usds: int256(usds.totalSupply()) - previousTotalSupply.usds,
            sky:  int256(sky.totalSupply())  - previousTotalSupply.sky
        });

        if (ignoreTotalSupplyDaiUsds == false) {
            // Assume USDS or Dai payments are made form the surplus buffer, meaning new ERC-20 tokens are emitted
            assertEq(
                totalSupplyDiff.dai + totalSupplyDiff.usds,
                calculatedTotalPayments.dai + calculatedTotalPayments.usds,
                "TestPayments/invalid-dai-usds-total"
            );
            // Check that dai/usds transfers modify surplus buffer
            assertEq(vat.sin(address(vow)) - previousSurplusBalance, uint256(calculatedTotalPayments.dai + calculatedTotalPayments.usds) * RAY);
        }

        TreasuryAmounts memory treasuryBalancesDiff = TreasuryAmounts({
            mkr: int256(mkr.balanceOf(pauseProxy)) - previousTreasuryBalances.mkr,
            sky: int256(sky.balanceOf(pauseProxy)) - previousTreasuryBalances.sky
        });
        if (ignoreTotalSupplyMkrSky == false) {
            assertEq(
                expectedTreasuryBalancesDiff.mkr,
                treasuryBalancesDiff.mkr,
                "TestPayments/actual-vs-expected-mkr-treasury-mismatch"
            );

            assertEq(
                expectedTreasuryBalancesDiff.sky,
                treasuryBalancesDiff.sky,
                "TestPayments/actual-vs-expected-sky-treasury-mismatch"
            );
            // Sky or MKR payments might come from token emission or from the treasury
            assertEq(
                (totalSupplyDiff.mkr - treasuryBalancesDiff.mkr) * int256(afterSpell.sky_mkr_rate)
                    + totalSupplyDiff.sky - treasuryBalancesDiff.sky,
                calculatedTotalPayments.mkr * int256(afterSpell.sky_mkr_rate)
                    + calculatedTotalPayments.sky,
                "TestPayments/invalid-mkr-sky-total"
            );
        }

        // Check that payees received their payments
        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i].token == address(dai)) {
                assertEq(
                    int256(dai.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].dai + payees[i].amount,
                    "TestPayments/invalid-payee-dai-balance"
                );
            } else if (payees[i].token == address(mkr)) {
                assertEq(
                    int256(mkr.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].mkr + payees[i].amount,
                    "TestPayments/invalid-payee-mkr-balance"
                );
            } else if (payees[i].token == address(usds)) {
                assertEq(
                    int256(usds.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].usds + payees[i].amount,
                    "TestPayments/invalid-payee-usds-balance"
                );
            } else if (payees[i].token == address(sky)) {
                assertEq(
                    int256(sky.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].sky + payees[i].amount,
                    "TestPayments/invalid-payee-sky-balance"
                );
            } else {
                revert('TestPayments/unexpected-payee-token');
            }
        }
    }

    function testNewCronJobs() public skipped { // add the `skipped` modifier to skip
        SequencerLike seq = SequencerLike(addr.addr("CRON_SEQUENCER"));
        address[1] memory newJobs = [
            addr.addr("CRON_STARGUARD_JOB")
        ];

        for (uint256 i = 0; i < newJobs.length; i++) {
            assertFalse(seq.hasJob(newJobs[i]), "TestError/cron-job-already-in-sequencer");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < newJobs.length; i++) {
            assertTrue(seq.hasJob(newJobs[i]), "TestError/cron-job-not-added-to-sequencer");
        }
    }

    function _setupRootDomain() internal {
        vm.makePersistent(address(spell), address(spell.action()), address(addr));

        string memory root = string.concat(vm.projectRoot(), "/lib/dss-test");
        config = ScriptTools.readInput(root, "integration");

        rootDomain = new RootDomain(config, getRelativeChain("mainnet"));
    }

    function testL2OptimismSpell() public skipped { // TODO: check if this test can be removed for good.
        address l2TeleportGateway = BridgeLike(
            chainLog.getAddress("OPTIMISM_TELEPORT_BRIDGE")
        ).l2TeleportGateway();

        _setupRootDomain();

        optimismDomain = new OptimismDomain(config, getRelativeChain("optimism"), rootDomain);
        optimismDomain.selectFork();

        // Check that the L2 Optimism Spell is there and configured
        L2Spell optimismSpell = L2Spell(0x9495632F53Cc16324d2FcFCdD4EB59fb88dDab12);

        L2Gateway optimismGateway = L2Gateway(optimismSpell.gateway());
        assertEq(address(optimismGateway), l2TeleportGateway, "l2-optimism-wrong-gateway");

        bytes32 optDstDomain = optimismSpell.dstDomain();
        assertEq(optDstDomain, bytes32("ETH-MAIN-A"), "l2-optimism-wrong-dst-domain");

        // Validate pre-spell optimism state
        assertEq(optimismGateway.validDomains(optDstDomain), 1, "l2-optimism-invalid-dst-domain");
        // Cast the L1 Spell
        rootDomain.selectFork();

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // switch to Optimism domain and relay the spell from L1
        // the `true` keeps us on Optimism rather than `rootDomain.selectFork()
        optimismDomain.relayFromHost(true);

        // Validate post-spell state
        assertEq(optimismGateway.validDomains(optDstDomain), 0, "l2-optimism-invalid-dst-domain");
    }

    function testL2ArbitrumSpell() public skipped { // TODO: check if this test can be removed for good.
        // Ensure the Arbitrum Gov Relay has some ETH to pay for the Arbitrum spell
        assertGt(chainLog.getAddress("ARBITRUM_GOV_RELAY").balance, 0);

        address l2TeleportGateway = BridgeLike(
            chainLog.getAddress("ARBITRUM_TELEPORT_BRIDGE")
        ).l2TeleportGateway();

        _setupRootDomain();

        arbitrumDomain = new ArbitrumDomain(config, getRelativeChain("arbitrum_one"), rootDomain);
        arbitrumDomain.selectFork();

        // Check that the L2 Arbitrum Spell is there and configured
        L2Spell arbitrumSpell = L2Spell(0x852CCBB823D73b3e35f68AD6b14e29B02360FD3d);

        L2Gateway arbitrumGateway = L2Gateway(arbitrumSpell.gateway());
        assertEq(address(arbitrumGateway), l2TeleportGateway, "l2-arbitrum-wrong-gateway");

        bytes32 arbDstDomain = arbitrumSpell.dstDomain();
        assertEq(arbDstDomain, bytes32("ETH-MAIN-A"), "l2-arbitrum-wrong-dst-domain");

        // Validate pre-spell arbitrum state
        assertEq(arbitrumGateway.validDomains(arbDstDomain), 1, "l2-arbitrum-invalid-dst-domain");

        // Cast the L1 Spell
        rootDomain.selectFork();

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // switch to Arbitrum domain and relay the spell from L1
        // the `true` keeps us on Arbitrum rather than `rootDomain.selectFork()
        arbitrumDomain.relayFromHost(true);

        // Validate post-spell state
        assertEq(arbitrumGateway.validDomains(arbDstDomain), 0, "l2-arbitrum-invalid-dst-domain");
    }

    function testOffboardings() public skipped { // add the `skipped` modifier to skip
        uint256 Art;
        (Art,,,,) = vat.ilks("USDC-A");
        assertGt(Art, 0);
        (Art,,,,) = vat.ilks("PAXUSD-A");
        assertGt(Art, 0);
        (Art,,,,) = vat.ilks("GUSD-A");
        assertGt(Art, 0);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        DssCdpManagerAbstract cdpManager = DssCdpManagerAbstract(addr.addr("CDP_MANAGER"));

        dog.bark("USDC-A", cdpManager.urns(14981), address(0));
        dog.bark("USDC-A", 0x936d9045E7407aBE8acdBaF34EAe4023B44cEfE2, address(0));
        dog.bark("USDC-A", cdpManager.urns(10791), address(0));
        dog.bark("USDC-A", cdpManager.urns(9529), address(0));
        dog.bark("USDC-A", cdpManager.urns(7062), address(0));
        dog.bark("USDC-A", cdpManager.urns(13008), address(0));
        dog.bark("USDC-A", cdpManager.urns(18152), address(0));
        dog.bark("USDC-A", cdpManager.urns(15504), address(0));
        dog.bark("USDC-A", cdpManager.urns(17116), address(0));
        dog.bark("USDC-A", cdpManager.urns(20087), address(0));
        dog.bark("USDC-A", cdpManager.urns(21551), address(0));
        dog.bark("USDC-A", cdpManager.urns(12964), address(0));
        dog.bark("USDC-A", cdpManager.urns(7361), address(0));
        dog.bark("USDC-A", cdpManager.urns(12588), address(0));
        dog.bark("USDC-A", cdpManager.urns(13641), address(0));
        dog.bark("USDC-A", cdpManager.urns(18786), address(0));
        dog.bark("USDC-A", cdpManager.urns(14676), address(0));
        dog.bark("USDC-A", cdpManager.urns(20189), address(0));
        dog.bark("USDC-A", cdpManager.urns(15149), address(0));
        dog.bark("USDC-A", cdpManager.urns(7976), address(0));
        dog.bark("USDC-A", cdpManager.urns(16639), address(0));
        dog.bark("USDC-A", cdpManager.urns(8724), address(0));
        dog.bark("USDC-A", cdpManager.urns(7170), address(0));
        dog.bark("USDC-A", cdpManager.urns(7337), address(0));
        dog.bark("USDC-A", cdpManager.urns(14142), address(0));
        dog.bark("USDC-A", cdpManager.urns(12753), address(0));
        dog.bark("USDC-A", cdpManager.urns(9579), address(0));
        dog.bark("USDC-A", cdpManager.urns(14628), address(0));
        dog.bark("USDC-A", cdpManager.urns(15288), address(0));
        dog.bark("USDC-A", cdpManager.urns(16139), address(0));
        dog.bark("USDC-A", cdpManager.urns(12287), address(0));
        dog.bark("USDC-A", cdpManager.urns(11908), address(0));
        dog.bark("USDC-A", cdpManager.urns(8829), address(0));
        dog.bark("USDC-A", cdpManager.urns(7925), address(0));
        dog.bark("USDC-A", cdpManager.urns(10430), address(0));
        dog.bark("USDC-A", cdpManager.urns(11122), address(0));
        dog.bark("USDC-A", cdpManager.urns(12663), address(0));
        dog.bark("USDC-A", cdpManager.urns(9027), address(0));
        dog.bark("USDC-A", cdpManager.urns(8006), address(0));
        dog.bark("USDC-A", cdpManager.urns(12693), address(0));
        dog.bark("USDC-A", cdpManager.urns(7079), address(0));
        dog.bark("USDC-A", cdpManager.urns(12220), address(0));
        dog.bark("USDC-A", cdpManager.urns(8636), address(0));
        dog.bark("USDC-A", cdpManager.urns(8643), address(0));
        dog.bark("USDC-A", cdpManager.urns(6992), address(0));
        dog.bark("USDC-A", cdpManager.urns(7083), address(0));
        dog.bark("USDC-A", cdpManager.urns(7102), address(0));
        dog.bark("USDC-A", cdpManager.urns(7124), address(0));
        dog.bark("USDC-A", cdpManager.urns(7328), address(0));
        dog.bark("USDC-A", cdpManager.urns(8053), address(0));
        dog.bark("USDC-A", cdpManager.urns(12246), address(0));
        dog.bark("USDC-A", cdpManager.urns(7829), address(0));
        dog.bark("USDC-A", cdpManager.urns(8486), address(0));
        dog.bark("USDC-A", cdpManager.urns(8677), address(0));
        dog.bark("USDC-A", cdpManager.urns(8700), address(0));
        dog.bark("USDC-A", cdpManager.urns(9139), address(0));
        dog.bark("USDC-A", cdpManager.urns(9240), address(0));
        dog.bark("USDC-A", cdpManager.urns(9250), address(0));
        dog.bark("USDC-A", cdpManager.urns(9144), address(0));
        dog.bark("USDC-A", cdpManager.urns(9568), address(0));
        dog.bark("USDC-A", cdpManager.urns(10773), address(0));
        dog.bark("USDC-A", cdpManager.urns(11404), address(0));
        dog.bark("USDC-A", cdpManager.urns(11609), address(0));
        dog.bark("USDC-A", cdpManager.urns(11856), address(0));
        dog.bark("USDC-A", cdpManager.urns(12355), address(0));
        dog.bark("USDC-A", cdpManager.urns(12778), address(0));
        dog.bark("USDC-A", cdpManager.urns(12632), address(0));
        dog.bark("USDC-A", cdpManager.urns(12747), address(0));
        dog.bark("USDC-A", cdpManager.urns(12679), address(0));

        dog.bark("PAXUSD-A", cdpManager.urns(14896), address(0));

        vm.store(
            address(dog),
            bytes32(uint256(keccak256(abi.encode(bytes32("GUSD-A"), uint256(1)))) + 2),
            bytes32(type(uint256).max)
        ); // Remove GUSD-A hole limit to reach the objective of the testing 0 debt after all barks
        dog.bark("GUSD-A", cdpManager.urns(24382), address(0));
        dog.bark("GUSD-A", cdpManager.urns(23939), address(0));
        dog.bark("GUSD-A", cdpManager.urns(25398), address(0));

        (Art,,,,) = vat.ilks("USDC-A");
        assertEq(Art, 0, "USDC-A Art is not 0");
        (Art,,,,) = vat.ilks("PAXUSD-A");
        assertEq(Art, 0, "PAXUSD-A Art is not 0");
        (Art,,,,) = vat.ilks("GUSD-A");
        assertEq(Art, 0, "GUSD-A Art is not 0");
    }

    function testDaoResolutions() public skipped { // replace `view` with the `skipped` modifier to skip
        // For each resolution, add IPFS hash as item to the resolutions array
        // Initialize the array with the number of resolutions
        string[1] memory resolutions = [
            "bafkreidm3bqfiwv224m6w4zuabsiwqruy22sjfaxfvgx4kgcnu3wndxmva"
        ];

        string memory comma_separated_resolutions = "";
        for (uint256 i = 0; i < resolutions.length; i++) {
            comma_separated_resolutions = string.concat(comma_separated_resolutions, resolutions[i]);
            if (i + 1 < resolutions.length) {
                comma_separated_resolutions = string.concat(comma_separated_resolutions, ",");
            }
        }

        assertEq(SpellActionLike(spell.action()).dao_resolutions(), comma_separated_resolutions, "dao_resolutions/invalid-format");
    }

    struct AllocatorPayment {
        address vault;
        uint256 wad;
    }

    struct MscIlkValues {
        uint256 urnArt;
        uint256 ilkArt;
    }

    function _testExpectedMscValues(AllocatorPayment[2] memory payments, MscIlkValues[] memory expectedValues, uint256 expectedDaiVow) internal view {
        for(uint256 i = 0; i < payments.length; i++) {
            bytes32 ilk = AllocatorVaultLike(payments[i].vault).ilk();
            (, uint256 urnArt) = vat.urns(ilk, address(payments[i].vault));
            (uint256 ilkArt,,,,) = vat.ilks(ilk);

            assertEq(urnArt, expectedValues[i].urnArt, "MSC/invalid-urn-art");
            assertEq(ilkArt, expectedValues[i].ilkArt, "MSC/invalid-ilk-art");
        }

        uint256 daiVow = vat.dai(address(vow));

        assertEq(daiVow, expectedDaiVow, "MSC/invalid-dai-value");
    }

    function testMonthlySettlementCycleInflows() public skipped { // add the `skipped` modifier to skip
        address ALLOCATOR_BLOOM_A_VAULT = addr.addr("ALLOCATOR_BLOOM_A_VAULT");
        address ALLOCATOR_SPARK_A_VAULT = addr.addr("ALLOCATOR_SPARK_A_VAULT");

        AllocatorPayment[2] memory payments = [
            AllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_931_086 * WAD),
            AllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_382_973 * WAD)
        ];

        uint256 expectedTotalAmount = 23_314_059 * WAD;

        MscIlkValues[] memory expectedValues = new MscIlkValues[](payments.length);
        uint256 totalDtab = 0;
        uint256 totalPayments = 0;

        uint256 before = vm.snapshotState();

        for(uint256 i = 0; i < payments.length; i++) {
            bytes32 ilk = AllocatorVaultLike(payments[i].vault).ilk();
            (, uint256 urnArt) = vat.urns(ilk, address(payments[i].vault));
            (uint256 ilkArt,,,,) = vat.ilks(ilk);

            uint256 rate = jug.drip(ilk);
            uint256 dart = payments[i].wad > 0 ? ((payments[i].wad * RAY - 1) / rate) + 1 : 0;

            totalPayments += payments[i].wad;
            totalDtab += dart * rate;
            expectedValues[i] = MscIlkValues(urnArt + dart, ilkArt + dart);
        }
        assertEq(totalPayments, expectedTotalAmount, "MSC/invalid-total-amount");

        uint256 expectedDaiVow = vat.dai(address(vow)) + totalDtab;

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Test with MCD_JUG.drip() having been called in the same block
        _testExpectedMscValues(payments, expectedValues, expectedDaiVow);

        vm.revertToStateAndDelete(before);


        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Test without prior MCD_JUG.drip()
        _testExpectedMscValues(payments, expectedValues, expectedDaiVow);
    }

    // Spark tests
    function testSparkSpellIsExecuted() public skipped { // add the `skipped` modifier to skip
        address SPARK_PROXY = addr.addr('SPARK_SUBPROXY');
        address SPARK_SPELL = address(0x71059EaAb41D6fda3e916bC9D76cB44E96818654); // Insert Spark spell address

        vm.expectCall(
            SPARK_PROXY,
            /* value = */ 0,
            abi.encodeCall(
                ProxyLike(SPARK_PROXY).exec,
                (SPARK_SPELL, abi.encodeWithSignature("execute()"))
            )
        );

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
    }

    // Bloom/Grove tests
    function testBloomSpellIsExecuted() public skipped { // add the `skipped` modifier to skip
        address BLOOM_PROXY = addr.addr('ALLOCATOR_BLOOM_A_SUBPROXY');
        address BLOOM_SPELL = address(0x8b4A92f8375ef89165AeF4639E640e077d7C656b); // Insert Bloom spell address

        vm.expectCall(
            BLOOM_PROXY,
            /* value = */ 0,
            abi.encodeCall(
                ProxyLike(BLOOM_PROXY).exec,
                (BLOOM_SPELL, abi.encodeWithSignature("execute()"))
            )
        );

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
    }

    // Nova/Keel tests
    function testNovaSpellIsExecuted() public skipped { // add the `skipped` modifier to skip
        address NOVA_PROXY = addr.addr('ALLOCATOR_NOVA_A_SUBPROXY');
        address NOVA_SPELL = address(0x7ae136b7e677C6A9B909a0ef0a4E29f0a1c3c7fE); // Insert Nova spell address

        vm.expectCall(
            NOVA_PROXY,
            /* value = */ 0,
            abi.encodeCall(
                ProxyLike(NOVA_PROXY).exec,
                (NOVA_SPELL, abi.encodeWithSignature("execute()"))
            )
        );

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
    }

    // SPELL-SPECIFIC TESTS GO BELOW

    event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel);

    address NTT_MANAGER = 0x7d4958454a3f520bDA8be764d06591B054B0bf33;
    WormholeLike WH_CORE_BRIDGE = WormholeLike(0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B);
    uint32  SOL_EID = 30168;

    address USDS_OFT_PAUSER = 0x38d1114b4cE3e079CC0f627df6aC2776B5887776;
    address LZ_GOV_SENDER = addr.addr("LZ_GOV_SENDER");
    address USDS_OFT = addr.addr("USDS_OFT");

    SkyOFTAdapterLike oft = SkyOFTAdapterLike(USDS_OFT);

    function testMigrationStep1() public {
        bytes memory payloadTransferMintAuth = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006856f43abf4aaa4a26b32ae8ea4cb8fadc8e02d267703fbd5f9dad85f6d00b300056f776e65720000000000000000000000000000000000000000000000000000000100b53f200f8db357f9e1e982ef0ec4b3b879f9f6516d5247307ebaf00d187be51a00009f92dcb365df21a4a4ec23d8ff4cc020cdd09895f8129c2c2fb43289bc53f95f00000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000106ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a90000002857edbb54a8aff14b9825dc0cbeaf22836931c00cb891592f0a96d0dc6a65a4c67992b01e0db8d122";
        bytes memory payloadTransferFreezeAuth = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc006ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a900020707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af00016f776e6572000000000000000000000000000000000000000000000000000000010000230601018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b";
        bytes memory payloadTransferMetadataUpdateAuth = hex"000000000000000047656e6572616c507572706f7365476f7665726e616e636502000106742d7ca523a03aaafe48abab02e47eb8aef53415cb603c47a3ccf864d86dc00b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f82946000b6f776e657200000000000000000000000000000000000000000000000000000001000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000707312d1d41da71f0fb280c1662cd65ebeb2e0859c0cbae3fdbdcb26c86e0af000071809dfc828921f70659869a0822bf04c42b823d518bfc11fe9a7b65d221a58f00010b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000706179657200000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000000000006a7d517187bd16635dad40455fdc2c0c124c68f215675a5dbbacb5f0800000000000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f8294600000b7065b1e3d17c45389d527f6b04c3cd58b86c731aa0fdb549b6d1bc03f829460000002c3201018dc412529f876c9f3bc01d7c3095bcd6cd1d6d5177b59aa03f04e5c5b422147b000000000000000000";

        uint256 oftPreviousBalance = usds.balanceOf(USDS_OFT);
        uint256 nttManagerPreviousBalance = usds.balanceOf(NTT_MANAGER);

        // Check pauser address
        assertTrue(oft.pausers(USDS_OFT_PAUSER), "TestError/MigrationStep1/pauser-mismatch");

        // Send OFT doesn't work yet
        SkyOFTAdapterLike.SendParam memory sendParams = SkyOFTAdapterLike.SendParam({
            dstEid: SOL_EID,
            to: bytes32("SolanaAddress"),
            amountLD: 5 * WAD,
            minAmountLD: 5 * WAD,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        SkyOFTAdapterLike.MessagingFee memory msgFee = oft.quoteSend(sendParams, false);

        GodMode.setBalance(address(usds), address(this), 10 * WAD);
        GemAbstract(usds).approve(USDS_OFT, 10 * WAD);
        vm.deal(address(this), 10 ether);

        uint256 usdsBalanceBeforeSend = usds.balanceOf(address(this));

        vm.expectRevert();
        oft.send{value: msgFee.nativeFee}(sendParams, msgFee, payable(address(this)));

        {
            /// Execute spell

            _vote(address(spell));

            // _scheduleWaitAndCast run manually to capture the wormhole event
            spell.schedule();
            vm.warp(spell.nextCastTime());

            uint64 sequence = WH_CORE_BRIDGE.nextSequence(pauseProxy);

            // NTT Manager transfer mint authority event
            vm.expectEmit(true, true, true, true, address(WH_CORE_BRIDGE));
            emit LogMessagePublished(pauseProxy, sequence, 0, payloadTransferMintAuth, 202);
            // NTT Manager transfer freeze authority event
            vm.expectEmit(true, true, true, true, address(WH_CORE_BRIDGE));
            emit LogMessagePublished(pauseProxy, sequence + 1, 0, payloadTransferFreezeAuth, 202);
            // NTT Manager transfer metadata update event
            vm.expectEmit(true, true, true, true, address(WH_CORE_BRIDGE));
            emit LogMessagePublished(pauseProxy, sequence + 2, 0, payloadTransferMetadataUpdateAuth, 202);

            spell.cast();
            assertTrue(spell.done(), "TestError/spell-not-done");
        }

        // Check locked token migration
        uint256 oftAfterBalance = usds.balanceOf(USDS_OFT);
        uint256 nttManagerAfterBalance = usds.balanceOf(NTT_MANAGER);
        assertGe(
            oftAfterBalance,
            oftPreviousBalance + nttManagerPreviousBalance,
            "TestError/MigrationStep1/oft-adapter-balance-not-increased"
        );
        assertEq(
            nttManagerAfterBalance,
            0,
            "TestError/MigrationStep1/ntt-manager-balance-not-zero"
        );

        // Check rate limit settings
        (,uint48 outWindow2,,uint256 outLimit2) = oft.outboundRateLimits(SOL_EID);
        (,uint48  inWindow2,,uint256  inLimit2) = oft.inboundRateLimits(SOL_EID);
        assertEq(outWindow2, 1 days,          "TestError/MigrationStep1/outWindow-rl-not-set");
        assertEq(inWindow2, 1 days,           "TestError/MigrationStep1/inWindow-rl-not-set");
        assertEq(outLimit2, 10_000_000 * WAD, "TestError/MigrationStep1/outLimit-rl-not-set");
        assertEq(inLimit2, 10_000_000 * WAD,  "TestError/MigrationStep1/inLimit-rl-not-set");

        // OFT send works now
        oft.send{value: msgFee.nativeFee}(sendParams, msgFee, payable(address(this)));
        assertEq(
            usds.balanceOf(address(this)),
            usdsBalanceBeforeSend - sendParams.amountLD,
            "TestError/MigrationStep1/oft-send-didnt-work"
        );

        // Pause oft as pauser
        vm.startPrank(USDS_OFT_PAUSER);
        oft.pause();
        vm.stopPrank();
        assertTrue(oft.paused(), "TestError/MigrationStep1/failed-to-pause");

        // Check owner(pauseProxy) can unpause
        vm.startPrank(pauseProxy);
        oft.unpause();
        vm.stopPrank();
        assertFalse(oft.paused(), "TestError/MigrationStep1/failed-to-unpause");
    }

    function testGovernanceRelayInit() public {
        L1GovernanceRelayLike l1GovernanceRelay = L1GovernanceRelayLike(addr.addr("LZ_GOV_RELAY"));
        GovernanceOAppSenderLike govOappSender = GovernanceOAppSenderLike(LZ_GOV_SENDER);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(l1GovernanceRelay.l1Oapp(), address(govOappSender), "governance-relay-init/wrong-l1-oapp");

        vm.startPrank(pauseProxy);
        address fakeL2GovernanceRelay = makeAddr('fakeL2GovernanceRelay');

        vm.deal(address(pauseProxy), 10 ether);
        uint256 nativeFee = 1 ether;

        // Relay to EVM L2 (e.g., Arbitrum)
        uint32 arbitrumEid = 30110;
        govOappSender.setPeer(arbitrumEid, bytes32(uint256(uint160(fakeL2GovernanceRelay))));
        govOappSender.setCanCallTarget(address(l1GovernanceRelay), arbitrumEid, bytes32(uint256(uint160(fakeL2GovernanceRelay))), true);
        l1GovernanceRelay.relayEVM{value: nativeFee}({
            dstEid            : arbitrumEid,
            l2GovernanceRelay : fakeL2GovernanceRelay,
            target            : address(0x222),
            targetData        : bytes("789"),
            extraOptions      : hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0",
            fee : L1GovernanceRelayLike.MessagingFee({
                nativeFee  : nativeFee,
                lzTokenFee : 0
            }),
            refundAddress     : address(0x333)
        });

        // Relay to Solana
        govOappSender.setCanCallTarget(address(l1GovernanceRelay), SOL_EID, bytes32(uint256(uint160(fakeL2GovernanceRelay))), true);
        l1GovernanceRelay.relayRaw{value: nativeFee}({
            txParams : L1GovernanceRelayLike.TxParams({
                dstEid            : SOL_EID,
                dstTarget         : bytes32(uint256(uint160(fakeL2GovernanceRelay))),
                dstCallData       : abi.encodeWithSelector(
                                        bytes4(keccak256("relay(address,string)")),
                                        bytes4(keccak256("relay(address,string)")),
                                        0x222,
                                        "789"
                                    ),
                extraOptions      : hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0"
            }),
            fee : L1GovernanceRelayLike.MessagingFee({
                nativeFee  : nativeFee,
                lzTokenFee : 0
            }),
            refundAddress : address(0x333)
        });

        vm.stopPrank();
    }
}
