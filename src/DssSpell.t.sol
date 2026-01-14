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

interface SpellActionLike {
    function dao_resolutions() external view returns (string memory);
}

interface VestedRewardsDistributionLike {
    function vestId() external view returns (uint256);
}

interface GovernanceOAppSenderLike {
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
    struct MessagingReceipt {
        bytes32 guid;
    }
    function canCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget) external view returns (bool);
    function sendTx(
        TxParams calldata _params,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt);
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

    function testAddedChainlogKeys() public skipped { // add the `skipped` modifier to skip
        string[2] memory addedKeys = [
            "CCEA1_SUBPROXY",
            "CCEA1_STARGUARD"
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

    function testIlkClipper() public {  // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

       _checkIlkClipper(
            "GUNIV3DAIUSDC1-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_GUNIV3DAIUSDC1_A")),
            ClipAbstract(addr.addr("MCD_CLIP_GUNIV3DAIUSDC1_A")),
            addr.addr("MCD_CLIP_CALC_GUNIV3DAIUSDC1_A"),
            OsmAbstract(addr.addr("PIP_GUNIV3DAIUSDC1")),
            1_000 * WAD
        );

        _checkIlkClipper(
            "GUNIV3DAIUSDC2-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_GUNIV3DAIUSDC2_A")),
            ClipAbstract(addr.addr("MCD_CLIP_GUNIV3DAIUSDC2_A")),
            addr.addr("MCD_CLIP_CALC_GUNIV3DAIUSDC2_A"),
            OsmAbstract(addr.addr("PIP_GUNIV3DAIUSDC2")),
            1_000 * WAD
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
            allocatorProxy: addr.addr("OBEX_SUBPROXY"),
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

    function testVestSky() public { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 JUN_15_2026_14_00_23 = 1781532023;

        uint256 spellCastTime = _getSpellCastTime();

        // Build expected new stream
        NewVestStream[] memory newStreams = new NewVestStream[](0);

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](1);
        yankedStreams[0] = YankedVestStream({
            id:  9,
            fin: JUN_15_2026_14_00_23,
            end: spellCastTime
        });

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

    function testVestSpk() public { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 JUN_23_2027_14_00_23 = 1813759223;
        uint256 spellCastTime = _getSpellCastTime();

        // For each new stream, provide Stream object and initialize the array with the current number of new streams
        NewVestStream[] memory newStreams = new NewVestStream[](0);

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](1);

        yankedStreams[0] = YankedVestStream({
            id: 2,
            fin: JUN_23_2027_14_00_23,
            end: spellCastTime
        });

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

    function testPayments() public { // add the `skipped` modifier to skip
        // Note: set to true when there are additional DAI/USDS operations (e.g. surplus buffer sweeps, SubDAO draw-downs) besides direct transfers
        bool ignoreTotalSupplyDaiUsds = false;
        bool ignoreTotalSupplyMkrSky = true;

        // For each payment, create a Payee object with:
        //    the address of the transferred token,
        //    the destination address,
        //    the amount to be paid
        // Initialize the array with the number of payees
        Payee[6] memory payees = [
            Payee(address(usds), wallets.addr("AEGIS_D"), 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BLUE"), 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BONAPUBLICA"), 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CLOAKY_2"), 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("TANGO"), 3_723 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("SKY_STAKING"), 1_032 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:                               0 ether, // Note: ether is only a keyword helper
            mkr:                               0 ether, // Note: ether is only a keyword helper
            usds:                         20_755 ether, // Note: ether is only a keyword helper
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
            // Assume USDS or Dai payments are made from the surplus buffer, meaning new ERC-20 tokens are emitted
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
            "bafkreifaflhcwe7jd5r3v7wmsq5tx7b56w5bcxjmgzgzqd6gwl3zrmkviq"
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
            AllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_332_535 * WAD),
            AllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 4_196_768 * WAD)
        ];

        uint256 expectedTotalAmount = 20_529_303 * WAD;

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

    struct PrimeAgentSpell {
        bytes32 starGuardKey;
        address addr;
        bytes32 codehash;
        bool directExecutionEnabled;
    }

    function testPrimeAgentSpellExecutions() public { // add the `skipped` modifier to skip
        PrimeAgentSpell[3] memory primeAgentSpells = [
            PrimeAgentSpell({
                starGuardKey: "SPARK_STARGUARD",                                              // Insert Prime Agent StarGuards Chainlog key
                addr: 0xCE352d9429A5e10b29D3d610C7217f9333e04aB4,                             // Insert Prime Agent spell address
                codehash: 0x10d1055c82acd9d6804cfb64a80decf3880a257b8af6adad603334325d2586ed, // Insert Prime Agent spell codehash
                directExecutionEnabled: false                                                 // Set to true if the Prime Agent spell is executed directly from core spell
            }),
            PrimeAgentSpell({
                starGuardKey: "GROVE_STARGUARD",
                addr: 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748,
                codehash: 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb,
                directExecutionEnabled: false
            }),
            PrimeAgentSpell({
                starGuardKey: "KEEL_STARGUARD",
                addr: 0x10AF705fB80bc115FCa83a6B976576Feb1E1aaca,
                codehash: 0xa231c2a3fa83669201d02335e50f6aa379a6319c5972cc046b588c08d91fd44d,
                directExecutionEnabled: false
            })
        ];

        uint256 before = vm.snapshotState();

        for (uint256 i = 0; i < primeAgentSpells.length; i++) {
            _testStarGuardExecution({
                starGuardKey: primeAgentSpells[i].starGuardKey,
                primeAgentSpell: primeAgentSpells[i].addr,
                primeAgentSpellHash: primeAgentSpells[i].codehash,
                directExecutionEnabled: primeAgentSpells[i].directExecutionEnabled
            });

            vm.revertToState(before);
        }
    }

    struct StarguardValues {
        address starGuard;
        address subProxy;
    }

    function testStarGuardInitialization() public skipped { // add the `skipped` modifier to skip
        StarguardValues[1] memory initializedStarGuards = [
            StarguardValues({
                starGuard: addr.addr("CCEA1_STARGUARD"), // Insert StarGuard address
                subProxy: addr.addr("CCEA1_SUBPROXY")    // Insert SubProxy address
            })
        ];

        for (uint256 i = 0; i < initializedStarGuards.length; i++) {
            address starGuard = initializedStarGuards[i].starGuard;
            address subProxy = initializedStarGuards[i].subProxy;

            _testStarGuardInitialization(starGuard, subProxy);
        }
    }

    // SPELL-SPECIFIC TESTS GO BELOW

    function testRewardsDistUsdsSkyUpdatedVestIdAndDistribute() public {
        address REWARDS_DIST_USDS_SKY = addr.addr("REWARDS_DIST_USDS_SKY");
        address REWARDS_USDS_SKY = addr.addr("REWARDS_USDS_SKY");

        uint256 vestId = VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).vestId();
        assertEq(vestId, 9, "TestError/rewards-dist-usds-sky-invalid-vest-id-before");

        uint256 unpaidAmount = vestSky.unpaid(9);
        assertTrue(unpaidAmount > 0, "TestError/rewards-dist-usds-sky-unpaid-zero-early");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        unpaidAmount = vestSky.unpaid(9);
        assertEq(unpaidAmount, 0, "TestError/rewards-dist-usds-sky-unpaid-not-cleared");

        assertEq(StakingRewardsLike(REWARDS_USDS_SKY).lastUpdateTime(), block.timestamp, "TestError/rewards-usds-sky-invalid-last-update-time");
    }

    function testRewardsDistLsskySpkUpdatedVestIdAndDistribute() public {
        address REWARDS_DIST_LSSKY_SPK = addr.addr("REWARDS_DIST_LSSKY_SPK");
        address REWARDS_LSSKY_SPK = addr.addr("REWARDS_LSSKY_SPK");

        uint256 vestId = VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).vestId();
        assertEq(vestId, 2, "TestError/rewards-dist-lssky-spk-invalid-vest-id-before");

        uint256 unpaidAmount = vestSpk.unpaid(2);
        assertTrue(unpaidAmount > 0, "TestError/rewards-dist-lssky-spk-unpaid-zero-early");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        unpaidAmount = vestSpk.unpaid(2);
        assertEq(unpaidAmount, 0, "TestError/rewards-dist-lssky-spk-unpaid-not-cleared");

        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).lastUpdateTime(), block.timestamp, "TestError/rewards-lssky-spk-invalid-last-update-time");
    }

    function testGUniV3DaiUsdc1Offboarding() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        LPOsmAbstract pip = LPOsmAbstract(chainLog.getAddress("PIP_GUNIV3DAIUSDC1"));

        _checkUNILPIntegration(
            "GUNIV3DAIUSDC1-A",
            GemJoinAbstract(chainLog.getAddress("MCD_JOIN_GUNIV3DAIUSDC1_A")),
            ClipAbstract(chainLog.getAddress("MCD_CLIP_GUNIV3DAIUSDC1_A")),
            pip,
            pip.orb0(),
            pip.orb1(),
            false,
            false,
            true
        );
    }

    function testGUniV3DaiUsdc2Offboarding() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        LPOsmAbstract pip = LPOsmAbstract(chainLog.getAddress("PIP_GUNIV3DAIUSDC2"));

        _checkUNILPIntegration(
            "GUNIV3DAIUSDC2-A",
            GemJoinAbstract(chainLog.getAddress("MCD_JOIN_GUNIV3DAIUSDC2_A")),
            ClipAbstract(chainLog.getAddress("MCD_CLIP_GUNIV3DAIUSDC2_A")),
            pip,
            pip.orb0(),
            pip.orb1(),
            false,
            false,
            true
        );
    }

    function testGovernanceCanCallTargetsAndHappyPath() public {
        uint32  SOL_EID = 30168;
        bytes32 SVM_CONTROLLER = 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;
        bytes32 BPF_LOADER     = 0x02a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a1004800000;

        address govSender    = addr.addr("LZ_GOV_SENDER");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertTrue(GovernanceOAppSenderLike(govSender).canCallTarget(addr.addr("KEEL_SUBPROXY"), SOL_EID, SVM_CONTROLLER), "GovernanceOAppSender/canCallTarget-not-set");
        assertTrue(GovernanceOAppSenderLike(govSender).canCallTarget(addr.addr("KEEL_SUBPROXY"), SOL_EID, BPF_LOADER), "GovernanceOAppSender/canCallTarget-not-set");

        // Happy path: call the Governance OApp sender directly from KEEL_SUBPROXY
        GovernanceOAppSenderLike govOappSender  = GovernanceOAppSenderLike(govSender);

        vm.startPrank(addr.addr("KEEL_SUBPROXY"));
        vm.deal(address(addr.addr("KEEL_SUBPROXY")), 10 ether);
        uint256 nativeFee = 1 ether;

        // Send to SVM_CONTROLLER (bytes("abc") is arbitrary payload)
        govOappSender.sendTx{value: nativeFee}(
            GovernanceOAppSenderLike.TxParams({
                dstEid      : SOL_EID,
                dstTarget   : SVM_CONTROLLER,
                dstCallData : bytes("abc"),
                extraOptions: hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0"
            }),
            GovernanceOAppSenderLike.MessagingFee({
                nativeFee  : nativeFee,
                lzTokenFee : 0
            }),
            address(0x333)
        );

        // Send to BPF_LOADER (bytes("def") is arbitrary payload)
        govOappSender.sendTx{value: nativeFee}(
            GovernanceOAppSenderLike.TxParams({
                dstEid      : SOL_EID,
                dstTarget   : BPF_LOADER,
                dstCallData : bytes("def"),
                extraOptions: hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0"
            }),
            GovernanceOAppSenderLike.MessagingFee({
                nativeFee  : nativeFee,
                lzTokenFee : 0
            }),
            address(0x333)
        );
        vm.stopPrank();
    }
}
