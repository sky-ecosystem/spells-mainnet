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
import {
    GovernanceOAppSenderLike,
    L1GovernanceRelayLike,
    LZLaneTesting,
    LzChainConfig,
    LzEnforcedOptionsConfig,
    LzExecutorConfig,
    LzLaneConfig,
    LzUlnConfig,
    RateLimitConfig,
    SkyOFTAdapterLike
} from "./test/helpers/LZLaneTesting.sol";

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

interface LineMomLike {
    function ilks(bytes32 ilk) external view returns (uint256);
    function wipe(bytes32 ilk) external returns (uint256);
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
        string[1] memory addedKeys = [
            "SUSDS_OFT"
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
        AllocatorIntegrationParams[2] memory params = [
            AllocatorIntegrationParams({
                ilk:            "ALLOCATOR-PRYSM-A",
                pip:            addr.addr("PIP_ALLOCATOR"),
                registry:       addr.addr("ALLOCATOR_REGISTRY"),
                roles:          addr.addr("ALLOCATOR_ROLES"),
                buffer:         addr.addr("ALLOCATOR_PRYSM_A_BUFFER"),
                vault:          addr.addr("ALLOCATOR_PRYSM_A_VAULT"),
                allocatorProxy: addr.addr("PRYSM_SUBPROXY"),
                owner:          addr.addr("MCD_PAUSE_PROXY")
            }),
            AllocatorIntegrationParams({
                ilk:            "ALLOCATOR-INTERVAL-A",
                pip:            addr.addr("PIP_ALLOCATOR"),
                registry:       addr.addr("ALLOCATOR_REGISTRY"),
                roles:          addr.addr("ALLOCATOR_ROLES"),
                buffer:         addr.addr("ALLOCATOR_INTERVAL_A_BUFFER"),
                vault:          addr.addr("ALLOCATOR_INTERVAL_A_VAULT"),
                allocatorProxy: addr.addr("INTERVAL_SUBPROXY"),
                owner:          addr.addr("MCD_PAUSE_PROXY")
            })
        ];

        // Sanity checks
        for(uint256 i = 0; i < params.length; i++) {
            require(AllocatorVaultLike(params[i].vault).ilk()      == params[i].ilk,         "AllocatorInit/vault-ilk-mismatch");
            require(AllocatorVaultLike(params[i].vault).roles()    == params[i].roles,       "AllocatorInit/vault-roles-mismatch");
            require(AllocatorVaultLike(params[i].vault).buffer()   == params[i].buffer,      "AllocatorInit/vault-buffer-mismatch");
            require(AllocatorVaultLike(params[i].vault).vat()      == address(vat),          "AllocatorInit/vault-vat-mismatch");
            require(AllocatorVaultLike(params[i].vault).usdsJoin() == address(usdsJoin),     "AllocatorInit/vault-usds-join-mismatch");
            require(AllocatorVaultLike(params[i].vault).wards(params[i].owner) == 1, "TestError/vault-owner-not-authed");
            require(WardsAbstract(params[i].buffer).wards(params[i].owner) == 1, "TestError/buffer-owner-not-authed");

            if (params[i].owner != params[i].allocatorProxy) {
                require(AllocatorVaultLike(params[i].vault).wards(params[i].allocatorProxy) == 0, "TestError/vault-allocator-proxy-authed-early");
                require(WardsAbstract(params[i].buffer).wards(params[i].allocatorProxy) == 0, "TestError/buffer-allocator-proxy-authed-early");
            }
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for(uint256 i = 0; i < params.length; i++) {
            _checkAllocatorIntegration(params[i]);

            // Note: skipped for this onboarding as no operators are added
            // Role and allowance checks - Specific to ALLOCATOR-BLOOM-A only
            // address allocatorOperator = wallets.addr("BLOOM_OPERATOR");
            // assertEq(usds.allowance(params[i].buffer, allocatorOperator), type(uint256).max);
            // assertTrue(AllocatorRolesLike(params[i].roles).hasActionRole("ALLOCATOR-BLOOM-A", params[i].vault, AllocatorVaultLike.draw.selector, 0));
            // assertTrue(AllocatorRolesLike(params[i].roles).hasActionRole("ALLOCATOR-BLOOM-A", params[i].vault, AllocatorVaultLike.wipe.selector, 0));

            // The allocator proxy should be able to call draw() wipe()
            vm.prank(params[i].allocatorProxy);
            AllocatorVaultLike(params[i].vault).draw(1_000 * WAD);
            assertEq(usds.balanceOf(params[i].buffer), 1_000 * WAD);

            vm.warp(block.timestamp + 1);
            jug.drip(params[i].ilk);

            vm.prank(params[i].allocatorProxy);
            AllocatorVaultLike(params[i].vault).wipe(1_000 * WAD);
            assertEq(usds.balanceOf(params[i].buffer), 0);
        }
    }

    function testNewLineMomIlks() public skipped { // add the `skipped` modifier to skip
        bytes32[2] memory ilks = [
            bytes32("ALLOCATOR-PRYSM-A"),
            bytes32("ALLOCATOR-INTERVAL-A")
        ];

        for (uint256 i = 0; i < ilks.length; i++) {
            assertEq(
                LineMomLike(address(lineMom)).ilks(ilks[i]),
                0,
                _concat("testNewLineMomIlks/before-ilk-already-in-lineMom-", ilks[i])
            );
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < ilks.length; i++) {
            assertEq(
                LineMomLike(address(lineMom)).ilks(ilks[i]),
                1,
                _concat("testNewLineMomIlks/after-ilk-not-added-to-lineMom-", ilks[i])
            );

            (uint256 lineBefore,,,,) = autoLine.ilks(ilks[i]);
            assertGt(lineBefore, 0, _concat("testNewLineMomIlks/before-autoLine-not-initialized-", ilks[i]));
            (,,, uint256 ilkVatLineBefore,) = vat.ilks(ilks[i]);
            assertGt(ilkVatLineBefore, 0, _concat("testNewLineMomIlks/before-vat-line-not-initialized-", ilks[i]));

            // Verify governance can trigger an emergency wipe for new onboarded ilks
            vm.prank(chief.hat());
            LineMomLike(address(lineMom)).wipe(ilks[i]);
            (uint256 lineAfter,,,,) = autoLine.ilks(ilks[i]);
            assertEq(lineAfter, 0, _concat("testNewLineMomIlks/after-autoLine-line-not-zero-", ilks[i]));
            (,,, uint256 ilkVatLineAfter,) = vat.ilks(ilks[i]);
            assertEq(ilkVatLineAfter, 0, _concat("testNewLineMomIlks/after-vat-line-not-zero-", ilks[i]));
        }
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
        uint256 AUG_29_2026_14_00_23 = 1788012023;

        uint256 spellCastTime = _getSpellCastTime();

        // Build expected new stream
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  11,
            usr: addr.addr("REWARDS_DIST_LSSKY_SKY"),
            bgn: spellCastTime,
            clf: spellCastTime,
            fin: spellCastTime + 90 days,
            tau: 90 days,
            mgr: address(0),
            res: 1,
            tot: 192_110_322 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](1);
        yankedStreams[0] = YankedVestStream({
            id:  10,
            fin: AUG_29_2026_14_00_23,
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

    function testVestSpk() public skipped { // add the `skipped` modifier to skip
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

    function testVestedRewardsDist() public {
        address rewardsDist = addr.addr("REWARDS_DIST_LSSKY_SKY");
        address stakingRewards = addr.addr("REWARDS_LSSKY_SKY");
        VestAbstract vest = VestAbstract(addr.addr("MCD_VEST_SKY_TREASURY"));
        uint256 expectedVestId = 10;

        uint256 vestId = VestedRewardsDistributionLike(rewardsDist).vestId();
        assertEq(vestId, expectedVestId, "TestError/rewards-dist-lssky-sky-invalid-vest-id-before");

        uint256 unpaidAmount = vest.unpaid(expectedVestId);
        assertTrue(unpaidAmount > 0, "TestError/rewards-dist-lssky-sky-unpaid-zero-early");

        _checkVestedRewardsDistributionRevertEdgeCase(rewardsDist);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        unpaidAmount = vest.unpaid(expectedVestId);
        assertEq(unpaidAmount, 0, "TestError/rewards-dist-lssky-sky-unpaid-not-cleared");

        // Check newly set vestId if updated
        vestId = VestedRewardsDistributionLike(rewardsDist).vestId();
        assertEq(vestId, 11, "TestError/rewards-dist-lssky-sky-invalid-vest-id-after");

        assertEq(StakingRewardsLike(stakingRewards).lastUpdateTime(), block.timestamp, "TestError/rewards-lssky-sky-invalid-last-update-time");
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
        Payee[1] memory payees = [
            Payee(address(usds), addr.addr("GROVE_SUBPROXY"), 20_797_477 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:           0 ether, // Note: ether is only a keyword helper
            mkr:           0 ether, // Note: ether is only a keyword helper
            usds: 20_797_477 ether, // Note: ether is only a keyword helper
            sky:           0 ether  // Note: ether is only a keyword helper
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

    function testBaseGovRelay() public skipped { // add the `skipped` modifier to skip
        _setupL2Domains();
        _testOpL2GovernanceRelay(
            "base",
            baseDomain,
            addr.addr("BASE_GOV_RELAY"),
            base.addr("L2_GOV_RELAY"),
            base.addr("L2_MESSENGER")
        );
    }

    function testOptimismGovRelay() public skipped { // add the `skipped` modifier to skip
        _setupL2Domains();
        _testOpL2GovernanceRelay(
            "optimism",
            optimismDomain,
            addr.addr("OPTIMISM_GOV_RELAY"),
            optimism.addr("L2_OPTIMISM_GOV_RELAY"),
            optimism.addr("L2_OPTIMISM_MESSENGER")
        );
    }

    function testUnichainGovRelay() public skipped { // add the `skipped` modifier to skip
        _setupL2Domains();
        _testOpL2GovernanceRelay(
            "unichain",
            unichainDomain,
            addr.addr("UNICHAIN_GOV_RELAY"),
            unichain.addr("L2_UNICHAIN_GOV_RELAY"),
            unichain.addr("L2_UNICHAIN_MESSENGER")
        );
    }

    function testArbitrumGovRelay() public skipped { // add the `skipped` modifier to skip
        _setupL2Domains();
        _testArbitrumL2GovernanceRelay(
            "arbitrum",
            addr.addr("ARBITRUM_GOV_RELAY"),
            arbitrum.addr("L2_GOV_RELAY")
        );
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
            "bafkreiczdjq55zsxvxcf4le3oaqvhp4jgvls4n4b7xbnzvkwilzen3a2te"
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

    function _testExpectedMscValues(AllocatorPayment[3] memory payments, MscIlkValues[] memory expectedValues, uint256 expectedDaiVow) internal view {
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
        address ALLOCATOR_SPARK_A_VAULT = addr.addr("ALLOCATOR_SPARK_A_VAULT");
        address ALLOCATOR_BLOOM_A_VAULT = addr.addr("ALLOCATOR_BLOOM_A_VAULT");
        address ALLOCATOR_OBEX_A_VAULT = addr.addr("ALLOCATOR_OBEX_A_VAULT");

        AllocatorPayment[3] memory payments = [
            AllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 7_746_811 * WAD),
            AllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 1_948_422 * WAD),
            AllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 6_346_829 * WAD)
        ];

        uint256 expectedTotalAmount = 16_042_062 * WAD;

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
        PrimeAgentSpell[2] memory primeAgentSpells = [
            PrimeAgentSpell({
                starGuardKey: "SPARK_STARGUARD",                                              // Insert Prime Agent StarGuards Chainlog key
                addr: 0xFa5fc020311fCC1A467FEC5886640c7dD746deAa,                             // Insert Prime Agent spell address
                codehash: 0x2572a97846f7a6f9f159a9a69c2707cfa4186c061de2a0ec59e7a0d46473c74c, // Insert Prime Agent spell codehash
                directExecutionEnabled: false                                                 // Set to true if the Prime Agent spell is executed directly from core spell
            }),
            PrimeAgentSpell({
                starGuardKey: "GROVE_STARGUARD",
                addr: 0x679eD4739c71300f7d78102AE5eE17EF8b8b2162,
                codehash: 0x4fa1f743b3d6d2855390724459129186dd684e1c07d59f88925f0059ba1e6c84,
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
        StarguardValues[2] memory initializedStarGuards = [
            StarguardValues({
                starGuard: addr.addr("OZONE_STARGUARD"), // Insert StarGuard address
                subProxy: addr.addr("OZONE_SUBPROXY")    // Insert SubProxy address
            }),
            StarguardValues({
                starGuard: addr.addr("AMATSU_STARGUARD"),
                subProxy: addr.addr("AMATSU_SUBPROXY")
            })
        ];

        for (uint256 i = 0; i < initializedStarGuards.length; i++) {
            address starGuard = initializedStarGuards[i].starGuard;
            address subProxy = initializedStarGuards[i].subProxy;

            _testStarGuardInitialization(starGuard, subProxy);
        }
    }

    struct ChainUpdates {
        string caip2ChainId;
        SafeHarborAgreementLike.Account[] addedAccounts;
    }

    function testUpdateSafeHarborAddedAccounts() public { // add the `skipped` modifier to skip
        SafeHarborAgreementLike agreement = SafeHarborAgreementLike(addr.addr("SAFE_HARBOR_AGREEMENT"));

        ChainUpdates[1] memory chainUpdates;

        // Build array of accounts to be added to Safe Harbor Agreement
        SafeHarborAgreementLike.Account[] memory addedAccounts = new SafeHarborAgreementLike.Account[](1);
        addedAccounts[0] = SafeHarborAgreementLike.Account({
            accountAddress: "0x85A3FE4DA2a6cB98A5bdF62458B0dB8471B9f0f1",
            ChildContractScope: 0
        });

        // Configure chain updates for eip155:1 with added accounts
        chainUpdates[0] = ChainUpdates({
            caip2ChainId: "eip155:1",
            addedAccounts: addedAccounts
        });

        // Check that added accounts are not present before spell execution
        for (uint256 i = 0; i < chainUpdates.length; i++) {
            SafeHarborAgreementLike.AgreementDetails memory details = agreement.getDetails();
            SafeHarborAgreementLike.Chain memory chain = _findChain(details, chainUpdates[i].caip2ChainId);

            for (uint256 j = 0; j < chainUpdates[i].addedAccounts.length; j++) {
                assertFalse(
                    _accountExistsInChain(chain, chainUpdates[i].addedAccounts[j].accountAddress),
                    string.concat("testUpdateSafeHarborAddedAccounts/account-already-present-before-spell-execution-", chainUpdates[i].addedAccounts[j].accountAddress)
                );
            }
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check that added accounts are present after spell execution
        for (uint256 i = 0; i < chainUpdates.length; i++) {
            SafeHarborAgreementLike.AgreementDetails memory details = agreement.getDetails();
            SafeHarborAgreementLike.Chain memory chain = _findChain(details, chainUpdates[i].caip2ChainId);

            for (uint256 j = 0; j < chainUpdates[i].addedAccounts.length; j++) {
                assertTrue(
                    _accountExistsInChain(chain, chainUpdates[i].addedAccounts[j].accountAddress),
                    string.concat("testUpdateSafeHarborAddedAccounts/safe-harbor-account-not-found-after-spell-execution-", chainUpdates[i].addedAccounts[j].accountAddress)
                );

                // Verify the account has the correct ChildContractScope
                SafeHarborAgreementLike.Account memory account = _findAccountInChain(chain, chainUpdates[i].addedAccounts[j].accountAddress);
                assertEq(
                    account.ChildContractScope,
                    chainUpdates[i].addedAccounts[j].ChildContractScope,
                    string.concat("testUpdateSafeHarborAddedAccounts/incorrect-scope-for-account-", chainUpdates[i].addedAccounts[j].accountAddress)
                );
            }
        }
    }

    // SPELL-SPECIFIC TESTS GO BELOW

    function testSafeHarborAvalancheOnboarding() public {
        SafeHarborAgreementLike agreement = SafeHarborAgreementLike(addr.addr("SAFE_HARBOR_AGREEMENT"));
        string memory avalancheChainId = "eip155:43114";

        // Verify Avalanche chain does not exist before spell
        SafeHarborAgreementLike.AgreementDetails memory detailsBefore = agreement.getDetails();
        for (uint256 i = 0; i < detailsBefore.chains.length; i++) {
            assertFalse(
                _compareStrings(detailsBefore.chains[i].caip2ChainId, avalancheChainId),
                "TestError/avalanche-chain-already-exists-before-spell"
            );
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Verify Avalanche chain exists after spell with the correct accounts
        SafeHarborAgreementLike.AgreementDetails memory detailsAfter = agreement.getDetails();
        SafeHarborAgreementLike.Chain memory avalancheChain = _findChain(detailsAfter, avalancheChainId);

        SafeHarborAgreementLike.Account[] memory expectedAccounts = new SafeHarborAgreementLike.Account[](8);
        expectedAccounts[0] = SafeHarborAgreementLike.Account({
            accountAddress:     "0x6fdd46947ca6903c8c159d1dF2012Bc7fC5cEeec", // GovernanceOAppReceiver
            ChildContractScope: 0
        });
        expectedAccounts[1] = SafeHarborAgreementLike.Account({
            accountAddress:     "0xe928885BCe799Ed933651715608155F01abA23cA", // L2GovernanceRelay
            ChildContractScope: 0
        });
        expectedAccounts[2] = SafeHarborAgreementLike.Account({
            accountAddress:     "0xB5bc5dFe65a9ec30738DB3a0b592B8a18A191300", // USDS implementation
            ChildContractScope: 0
        });
        expectedAccounts[3] = SafeHarborAgreementLike.Account({
            accountAddress:     "0x86Ff09db814ac346a7C6FE2Cd648F27706D1D470", // USDS proxy
            ChildContractScope: 0
        });
        expectedAccounts[4] = SafeHarborAgreementLike.Account({
            accountAddress:     "0x4fec40719fD9a8AE3F8E20531669DEC5962D2619", // SkyOFTAdapterMintBurn(USDS)
            ChildContractScope: 0
        });
        expectedAccounts[5] = SafeHarborAgreementLike.Account({
            accountAddress:     "0xc8dB83458e8593Ed9a2D81DC29068B12D330729a", // sUSDS implementation
            ChildContractScope: 0
        });
        expectedAccounts[6] = SafeHarborAgreementLike.Account({
            accountAddress:     "0xb94D9613C7aAB11E548a327154Cc80eCa911B5c1", // sUSDS proxy
            ChildContractScope: 0
        });
        expectedAccounts[7] = SafeHarborAgreementLike.Account({
            accountAddress:     "0x7297D4811f088FC26bC5475681405B99b41E1FF9", // SkyOFTAdapterMintBurn(sUSDS)
            ChildContractScope: 0
        });

        assertEq(avalancheChain.accounts.length, expectedAccounts.length, "TestError/avalanche-wrong-account-count");
        for (uint256 i = 0; i < expectedAccounts.length; i++) {
            SafeHarborAgreementLike.Account memory actual = _findAccountInChain(avalancheChain, expectedAccounts[i].accountAddress);
            assertEq(
                actual.ChildContractScope,
                expectedAccounts[i].ChildContractScope,
                string.concat("TestError/avalanche-account-child-contract-scope-mismatch-", expectedAccounts[i].accountAddress)
            );
        }
    }

    // --- LZ config tests ---

    error RateLimitExceeded();

    function testWireLzGovSenderAvalanche() public {
        LzChainConfig memory ethChain = _ethChain();
        LzLaneConfig memory lane = _avalancheGovLane();
        address govSender = addr.addr("LZ_GOV_SENDER");
        address govRelay = addr.addr("LZ_GOV_RELAY");
        bytes32 avalancheL2GovRelay = LZLaneTesting.toBytes32(avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY"));

        GovernanceOAppSenderLike govOapp = GovernanceOAppSenderLike(govSender);

        // Verify pre-spell state
        assertEq(govOapp.peers(lane.remoteEid), bytes32(0), "TestError/gov/peer-already-set");
        assertFalse(govOapp.canCallTarget(govRelay, lane.remoteEid, avalancheL2GovRelay), "TestError/gov/can-call-target-already-set");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        LZLaneTesting.assertOwner(govSender, lane);
        LZLaneTesting.assertDelegate(ethChain, govSender, lane);
        LZLaneTesting.assertPeerSet(govSender, lane);
        LZLaneTesting.assertSendLibrary(ethChain, govSender, lane);
        LZLaneTesting.assertSendExecutor(ethChain, govSender, lane);
        LZLaneTesting.assertSendUln(ethChain, govSender, lane);

        assertTrue(govOapp.canCallTarget(govRelay, lane.remoteEid, avalancheL2GovRelay), "TestError/gov/can-call-target-not-set");

        // L2 (Avalanche) — GovernanceOAppReceiver config (predeployed)
        LzChainConfig memory avalancheChain = _avalancheChain();
        LzLaneConfig memory govRemoteLane = _avalancheGovRemoteLane();
        address govReceiver = avalanche.addr("L2_AVALANCHE_LZ_GOV_RECEIVER");
        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        LZLaneTesting.assertOwner(govReceiver, govRemoteLane);
        LZLaneTesting.assertDelegate(avalancheChain, govReceiver, govRemoteLane);
        LZLaneTesting.assertPeerSet(govReceiver, govRemoteLane);
        LZLaneTesting.assertReceiveLibrary(avalancheChain, govReceiver, govRemoteLane);
        LZLaneTesting.assertReceiveUln(avalancheChain, govReceiver, govRemoteLane);
    }

    function testWireUsdsOftAvalanche() public {
        LzChainConfig memory ethChain = _ethChain();
        LzLaneConfig memory lane = _avalancheUsdsLane();
        address oapp = addr.addr("USDS_OFT");

        // Verify pre-spell state
        assertEq(SkyOFTAdapterLike(oapp).peers(lane.remoteEid), bytes32(0), "TestError/usds/peer-already-set");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // L1 (Ethereum) config
        LZLaneTesting.assertOwner(oapp, lane);
        LZLaneTesting.assertDelegate(ethChain, oapp, lane);
        LZLaneTesting.assertPeerSet(oapp, lane);
        LZLaneTesting.assertSendLibrary(ethChain, oapp, lane);
        LZLaneTesting.assertReceiveLibrary(ethChain, oapp, lane);
        LZLaneTesting.assertSendExecutor(ethChain, oapp, lane);
        LZLaneTesting.assertSendUln(ethChain, oapp, lane);
        LZLaneTesting.assertReceiveUln(ethChain, oapp, lane);
        LZLaneTesting.assertEnforcedOptions(oapp, lane);
        LZLaneTesting.assertOftSanity(oapp, lane.remoteEid, address(usds), 0);

        // L2 (Avalanche) config — predeployed; verify it matches
        LzChainConfig memory avalancheChain = _avalancheChain();
        LzLaneConfig memory reverseLane = _avalancheUsdsRemoteLane();
        address remoteOapp = avalanche.addr("L2_AVALANCHE_USDS_OFT");
        address avalancheUsdsToken = avalanche.addr("L2_AVALANCHE_USDS");
        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        LZLaneTesting.assertOwner(remoteOapp, reverseLane);
        LZLaneTesting.assertDelegate(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertPeerSet(remoteOapp, reverseLane);
        LZLaneTesting.assertSendLibrary(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertReceiveLibrary(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertSendExecutor(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertSendUln(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertReceiveUln(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertEnforcedOptions(remoteOapp, reverseLane);
        LZLaneTesting.assertOftSanity(remoteOapp, reverseLane.remoteEid, avalancheUsdsToken, 0);
    }

    function testWireSUsdsOftAvalanche() public {
        LzChainConfig memory ethChain = _ethChain();
        LzLaneConfig memory lane = _avalancheSUsdsLane();
        address oapp = addr.addr("SUSDS_OFT");

        // Verify SUSDS_OFT is not in chainlog before spell
        vm.expectRevert("dss-chain-log/invalid-key");
        chainLog.getAddress(_stringToBytes32("SUSDS_OFT"));

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(chainLog.getAddress(_stringToBytes32("SUSDS_OFT")), oapp, "TestError/susds/not-in-chainlog");
        assertTrue(SkyOFTAdapterLike(oapp).pausers(addr.addr("SUSDS_OFT_PAUSER")), "TestError/susds/pauser-not-set");

        LZLaneTesting.assertOwner(oapp, lane);
        LZLaneTesting.assertDelegate(ethChain, oapp, lane);
        LZLaneTesting.assertPeerSet(oapp, lane);
        LZLaneTesting.assertSendLibrary(ethChain, oapp, lane);
        LZLaneTesting.assertReceiveLibrary(ethChain, oapp, lane);
        LZLaneTesting.assertSendExecutor(ethChain, oapp, lane);
        LZLaneTesting.assertSendUln(ethChain, oapp, lane);
        LZLaneTesting.assertReceiveUln(ethChain, oapp, lane);
        LZLaneTesting.assertEnforcedOptions(oapp, lane);
        LZLaneTesting.assertOftSanity(oapp, lane.remoteEid, address(susds), 0);

        // L2 (Avalanche) — sUSDS OFT config (predeployed) + deployer ward check
        LzChainConfig memory avalancheChain = _avalancheChain();
        LzLaneConfig memory reverseLane = _avalancheSUsdsRemoteLane();
        address remoteOapp = avalanche.addr("L2_AVALANCHE_SUSDS_OFT");
        address avalancheSUsds    = avalanche.addr("L2_AVALANCHE_SUSDS");
        address avalancheDeployer = 0x48C4DbA0833748e576Ad60E12a3c01C5785b09Ab;

        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        LZLaneTesting.assertOwner(remoteOapp, reverseLane);
        LZLaneTesting.assertDelegate(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertPeerSet(remoteOapp, reverseLane);
        LZLaneTesting.assertSendLibrary(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertReceiveLibrary(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertSendExecutor(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertSendUln(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertReceiveUln(avalancheChain, remoteOapp, reverseLane);
        LZLaneTesting.assertEnforcedOptions(remoteOapp, reverseLane);
        LZLaneTesting.assertOftSanity(remoteOapp, reverseLane.remoteEid, avalancheSUsds, 0);

        assertEq(WardsAbstract(avalancheSUsds).wards(avalancheDeployer), 0, "TestError/susds/deployer-still-ward-on-avax-susds");
    }

    function testUsdsOftAvalancheRateLimits() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        SkyOFTAdapterLike oft = SkyOFTAdapterLike(addr.addr("USDS_OFT"));
        uint32 avalancheEid = _avalancheChain().eid;
        (, uint48 outW,, uint256 outL) = oft.outboundRateLimits(avalancheEid);
        (, uint48  inW,, uint256  inL) = oft.inboundRateLimits(avalancheEid);
        assertEq(outW, uint48(1 days), "TestError/usds/outbound-window-mismatch");
        assertEq(outL, 5_000_000 * WAD, "TestError/usds/outbound-limit-mismatch");
        assertEq(inW, uint48(1 days), "TestError/usds/inbound-window-mismatch");
        assertEq(inL, 5_000_000 * WAD, "TestError/usds/inbound-limit-mismatch");
    }

    struct OftPauseTestCase {
        address oft;
        address pauser;
        address owner;
        string  label;
    }

    function testOftPauseUnpause() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Capture all addresses before fork switch
        OftPauseTestCase[] memory ethCases = new OftPauseTestCase[](2);
        ethCases[0] = OftPauseTestCase({
            oft:    addr.addr("USDS_OFT"),
            pauser: addr.addr("SUSDS_OFT_PAUSER"),
            owner:  pauseProxy,
            label:  "eth-usds-oft"
        });
        ethCases[1] = OftPauseTestCase({
            oft:    addr.addr("SUSDS_OFT"),
            pauser: addr.addr("SUSDS_OFT_PAUSER"),
            owner:  pauseProxy,
            label:  "eth-susds-oft"
        });

        OftPauseTestCase[] memory avalancheCases = new OftPauseTestCase[](2);
        avalancheCases[0] = OftPauseTestCase({
            oft:    avalanche.addr("L2_AVALANCHE_USDS_OFT"),
            pauser: avalanche.addr("L2_AVALANCHE_OFT_PAUSER"),
            owner:  avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY"),
            label:  "avax-usds-oft"
        });
        avalancheCases[1] = OftPauseTestCase({
            oft:    avalanche.addr("L2_AVALANCHE_SUSDS_OFT"),
            pauser: avalanche.addr("L2_AVALANCHE_OFT_PAUSER"),
            owner:  avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY"),
            label:  "avax-susds-oft"
        });

        // Ethereum OFTs
        for (uint256 i = 0; i < ethCases.length; i++) {
            _assertPauseUnpause(ethCases[i]);
        }

        // Avalanche OFTs
        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        for (uint256 i = 0; i < avalancheCases.length; i++) {
            _assertPauseUnpause(avalancheCases[i]);
        }
    }

    function _assertPauseUnpause(OftPauseTestCase memory tc) internal {
        SkyOFTAdapterLike oft = SkyOFTAdapterLike(tc.oft);
        assertFalse(oft.paused(), string.concat("TestError/", tc.label, "/already-paused"));

        vm.prank(tc.pauser);
        oft.pause();
        assertTrue(oft.paused(), string.concat("TestError/", tc.label, "/not-paused"));

        vm.prank(tc.owner);
        oft.unpause();
        assertFalse(oft.paused(), string.concat("TestError/", tc.label, "/not-unpaused"));
    }

    function testGovernanceRelayAvalancheE2E() public {
        LzChainConfig memory ethChain = _ethChain();
        LzChainConfig memory avalancheChain = _avalancheChain();
        address govSender       = addr.addr("LZ_GOV_SENDER");
        address avalancheL2GovRelay  = avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY");
        address avalancheGovReceiver = avalanche.addr("L2_AVALANCHE_LZ_GOV_RECEIVER");
        address avalancheUsdsOft     = avalanche.addr("L2_AVALANCHE_USDS_OFT");
        uint256 ethFork = vm.activeFork();

        // Deploy a spell on Avalanche for the relay to delegatecall into
        uint256 avalancheFork = vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        address avalancheSpell = address(new AvalancheSetRateLimitsSpell());
        vm.selectFork(ethFork);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Build governance payload and send
        Vm.Log[] memory logs;
        {
            RateLimitConfig[] memory inbound = new RateLimitConfig[](1);
            inbound[0] = RateLimitConfig({
                eid:    ethChain.eid,
                window: uint48(1 days),
                limit:  10_000_000 * WAD
            });
            RateLimitConfig[] memory outbound = new RateLimitConfig[](1);
            outbound[0] = RateLimitConfig({
                eid:    ethChain.eid,
                window: uint48(1 days),
                limit:  10_000_000 * WAD
            });
            bytes memory targetData = abi.encodeWithSelector(AvalancheSetRateLimitsSpell.execute.selector, avalancheUsdsOft, inbound, outbound);

            vm.startPrank(pauseProxy);
            vm.deal(pauseProxy, 10 ether);
            vm.recordLogs();
            L1GovernanceRelayLike(addr.addr("LZ_GOV_RELAY")).relayEVM{value: 1 ether}(
                avalancheChain.eid,
                avalancheL2GovRelay,
                avalancheSpell,
                targetData,
                LZLaneTesting.executorLzReceiveOption(200_000),
                L1GovernanceRelayLike.MessagingFee({
                    nativeFee:  1 ether,
                    lzTokenFee: 0
                }),
                address(0xdead)
            );
            vm.stopPrank();
            logs = vm.getRecordedLogs();
        }

        // Relay to Avalanche and verify state
        LZLaneTesting.relayToFork(logs, ethChain, avalancheChain, govSender, avalancheGovReceiver, avalancheFork);
        vm.selectFork(avalancheFork);

        (, uint48 outW,, uint256 outL) = SkyOFTAdapterLike(avalancheUsdsOft).outboundRateLimits(ethChain.eid);
        (, uint48  inW,, uint256  inL) = SkyOFTAdapterLike(avalancheUsdsOft).inboundRateLimits(ethChain.eid);
        assertEq(outW, uint48(1 days), "TestError/gov/outbound-window-not-set");
        assertEq(outL, 10_000_000 * WAD, "TestError/gov/outbound-limit-not-set");
        assertEq(inW, uint48(1 days), "TestError/gov/inbound-window-not-set");
        assertEq(inL, 10_000_000 * WAD, "TestError/gov/inbound-limit-not-set");
    }

    function testUsdsOftAvalancheE2E() public {
        LzChainConfig memory ethChain = _ethChain();
        LzChainConfig memory avalancheChain = _avalancheChain();
        address oapp = addr.addr("USDS_OFT");
        address remoteOapp = avalanche.addr("L2_AVALANCHE_USDS_OFT");
        address avalancheUsds = avalanche.addr("L2_AVALANCHE_USDS");
        address recipient = makeAddr("avalanche-recipient");
        uint256 ethFork = vm.activeFork();

        // Capture Avalanche supply before
        uint256 avalancheFork = vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        uint256 avalancheSupplyBefore = GemAbstract(avalancheUsds).totalSupply();
        vm.selectFork(ethFork);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        uint256 sendAmount = 5 * WAD;
        uint256 ethSupplyBefore = usds.totalSupply();
        GodMode.setBalance(address(usds), address(this), sendAmount);
        GemAbstract(address(usds)).approve(oapp, sendAmount);
        vm.deal(address(this), 10 ether);

        // Forward leg: Ethereum → Avalanche
        {
            Vm.Log[] memory forwardLogs = LZLaneTesting.sendOft(SkyOFTAdapterLike(oapp), avalancheChain.eid, recipient, sendAmount, address(this));
            assertEq(usds.balanceOf(address(this)), 0, "TestError/usds/e2e-eth-sender-balance-not-zero-after-send");
            assertEq(usds.totalSupply(), ethSupplyBefore, "TestError/usds/e2e-eth-supply-changed-after-send");
            LZLaneTesting.relayToFork(forwardLogs, ethChain, avalancheChain, oapp, remoteOapp, avalancheFork);
        }
        vm.selectFork(avalancheFork);

        assertEq(GemAbstract(avalancheUsds).balanceOf(recipient), sendAmount, "TestError/usds/e2e-avax-not-received");
        assertEq(GemAbstract(avalancheUsds).totalSupply(), avalancheSupplyBefore + sendAmount, "TestError/usds/e2e-avax-not-minted");

        // Return leg: Avalanche → Ethereum
        {
            vm.startPrank(recipient);
            GemAbstract(avalancheUsds).approve(remoteOapp, sendAmount);
            vm.deal(recipient, 10 ether);
            Vm.Log[] memory returnLogs = LZLaneTesting.sendOft(SkyOFTAdapterLike(remoteOapp), ethChain.eid, address(this), sendAmount, recipient);
            vm.stopPrank();
            LZLaneTesting.relayToFork(returnLogs, avalancheChain, ethChain, remoteOapp, oapp, ethFork);
        }
        vm.selectFork(ethFork);

        assertEq(usds.totalSupply(), ethSupplyBefore, "TestError/usds/e2e-eth-supply-changed-after-roundtrip");
        assertEq(usds.balanceOf(address(this)), sendAmount, "TestError/usds/e2e-eth-not-unlocked");

        vm.selectFork(avalancheFork);
        assertEq(GemAbstract(avalancheUsds).balanceOf(recipient), 0, "TestError/usds/e2e-avax-not-burned");
        assertEq(GemAbstract(avalancheUsds).totalSupply(), avalancheSupplyBefore, "TestError/usds/e2e-avax-supply-not-restored");
    }

    function testSUsdsOftAvalancheRateLimitBlocked() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        address oapp = addr.addr("SUSDS_OFT");
        SkyOFTAdapterLike oft = SkyOFTAdapterLike(oapp);
        address susdsToken = oft.token();
        uint256 sendAmount = 5 * WAD;
        GodMode.setBalance(susdsToken, address(this), sendAmount);
        GemAbstract(susdsToken).approve(oapp, sendAmount);
        vm.deal(address(this), 10 ether);

        SkyOFTAdapterLike.SendParam memory sendParams = SkyOFTAdapterLike.SendParam({
            dstEid:       _avalancheChain().eid,
            to:           LZLaneTesting.toBytes32(address(this)),
            amountLD:     sendAmount,
            minAmountLD:  sendAmount,
            extraOptions: bytes(""),
            composeMsg:   bytes(""),
            oftCmd:       bytes("")
        });

        SkyOFTAdapterLike.MessagingFee memory msgFee = oft.quoteSend(sendParams, false);

        vm.expectRevert(RateLimitExceeded.selector);
        oft.send{value: msgFee.nativeFee}(sendParams, msgFee, payable(address(this)));
    }

    // --- Lane builders ---

    function _ethChain() internal view returns (LzChainConfig memory) {
        return LzChainConfig({
            eid:        30101,
            endpoint:   addr.addr("LZ_ENDPOINT"),
            sendLib302: addr.addr("LZ_SEND_302"),
            recvLib302: addr.addr("LZ_RECV_302")
        });
    }

    function _avalancheChain() internal view returns (LzChainConfig memory) {
        return LzChainConfig({
            eid:        30106,
            endpoint:   avalanche.addr("L2_AVALANCHE_LZ_ENDPOINT"),
            sendLib302: avalanche.addr("L2_AVALANCHE_LZ_SEND_302"),
            recvLib302: avalanche.addr("L2_AVALANCHE_LZ_RECV_302")
        });
    }

    function _avalancheGovLane() internal view returns (LzLaneConfig memory lane) {
        address[] memory optDVNs = new address[](7);
        optDVNs[0] = 0x06559EE34D85a88317Bf0bfE307444116c631b67; // P2P
        optDVNs[1] = 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4; // Deutsche Telekom
        optDVNs[2] = 0x380275805876Ff19055EA900CDb2B46a94ecF20D; // Horizen
        optDVNs[3] = 0x58249a2Ec05c1978bF21DF1f5eC1847e42455CF4; // Luganodes
        optDVNs[4] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        optDVNs[5] = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd; // Canary
        optDVNs[6] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        lane.remoteEid  = 30106;
        lane.remoteOApp = avalanche.addr("L2_AVALANCHE_LZ_GOV_RECEIVER");
        lane.owner      = pauseProxy;
        lane.sendExecutor = LzExecutorConfig({
            maxMessageSize: 10_000,
            executor: addr.addr("LZ_EXECUTOR")
        });
        lane.sendUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 0,
            optionalDVNCount: 7,
            optionalDVNThreshold: 4,
            requiredDVNs: new address[](0),
            optionalDVNs: optDVNs
        });
    }

    function _avalancheUsdsLane() internal view returns (LzLaneConfig memory lane) {
        address[] memory ethDVNs = new address[](2);
        ethDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        ethDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        lane.remoteEid  = 30106;
        lane.remoteOApp = avalanche.addr("L2_AVALANCHE_USDS_OFT");
        lane.owner      = pauseProxy;
        lane.sendExecutor = LzExecutorConfig({
            maxMessageSize: 10_000,
            executor: addr.addr("LZ_EXECUTOR")
        });

        lane.sendUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: ethDVNs,
            optionalDVNs: new address[](0)
        });
        lane.recvUln = LzUlnConfig({
            confirmations: 12,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: ethDVNs,
            optionalDVNs: new address[](0)
        });
        lane.enforcedOptions = LzEnforcedOptionsConfig({
            send:        LZLaneTesting.executorLzReceiveOption(130_000),
            sendAndCall: LZLaneTesting.executorLzReceiveOption(130_000)
        });
    }

    function _avalancheUsdsRemoteLane() internal view returns (LzLaneConfig memory lane) {
        address[] memory avalancheDVNs = new address[](2);
        avalancheDVNs[0] = 0x962F502A63F5FBeB44DC9ab932122648E8352959; // LayerZero Labs (Avalanche)
        avalancheDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        lane.remoteEid  = 30101;
        lane.remoteOApp = addr.addr("USDS_OFT");
        lane.owner      = avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY");
        lane.sendExecutor = LzExecutorConfig({
            maxMessageSize: 10_000,
            executor: avalanche.addr("L2_AVALANCHE_LZ_EXECUTOR")
        });

        lane.sendUln = LzUlnConfig({
            confirmations: 12,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: avalancheDVNs,
            optionalDVNs: new address[](0)
        });
        lane.recvUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: avalancheDVNs,
            optionalDVNs: new address[](0)
        });
        lane.enforcedOptions = LzEnforcedOptionsConfig({
            send:        LZLaneTesting.executorLzReceiveOption(130_000),
            sendAndCall: LZLaneTesting.executorLzReceiveOption(130_000)
        });
    }

    function _avalancheSUsdsLane() internal view returns (LzLaneConfig memory lane) {
        address[] memory ethDVNs = new address[](2);
        ethDVNs[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b; // LayerZero Labs
        ethDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        lane.remoteEid  = 30106;
        lane.remoteOApp = avalanche.addr("L2_AVALANCHE_SUSDS_OFT");
        lane.owner      = pauseProxy;
        lane.sendExecutor = LzExecutorConfig({
            maxMessageSize: 10_000,
            executor: addr.addr("LZ_EXECUTOR")
        });

        lane.sendUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: ethDVNs,
            optionalDVNs: new address[](0)
        });
        lane.recvUln = LzUlnConfig({
            confirmations: 12,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: ethDVNs,
            optionalDVNs: new address[](0)
        });
        lane.enforcedOptions = LzEnforcedOptionsConfig({
            send:        LZLaneTesting.executorLzReceiveOption(130_000),
            sendAndCall: LZLaneTesting.executorLzReceiveOption(130_000)
        });
    }

    function _avalancheSUsdsRemoteLane() internal view returns (LzLaneConfig memory lane) {
        address[] memory avalancheDVNs = new address[](2);
        avalancheDVNs[0] = 0x962F502A63F5FBeB44DC9ab932122648E8352959; // LayerZero Labs (Avalanche)
        avalancheDVNs[1] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind

        lane.remoteEid  = 30101;
        lane.remoteOApp = addr.addr("SUSDS_OFT");
        lane.owner      = avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY");
        lane.sendExecutor = LzExecutorConfig({
            maxMessageSize: 10_000,
            executor: avalanche.addr("L2_AVALANCHE_LZ_EXECUTOR")
        });

        lane.sendUln = LzUlnConfig({
            confirmations: 12,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: avalancheDVNs,
            optionalDVNs: new address[](0)
        });
        lane.recvUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: avalancheDVNs,
            optionalDVNs: new address[](0)
        });
        lane.enforcedOptions = LzEnforcedOptionsConfig({
            send:        LZLaneTesting.executorLzReceiveOption(130_000),
            sendAndCall: LZLaneTesting.executorLzReceiveOption(130_000)
        });
    }

    function _avalancheGovRemoteLane() internal view returns (LzLaneConfig memory lane) {
        // GovernanceOAppReceiver on Avalanche is receive-only: no send executor, no send ULN
        // It has a receive ULN config with 7 optional DVNs (Avalanche addresses)
        address[] memory avalancheOptDVNs = new address[](7);
        avalancheOptDVNs[0] = 0x07C05EaB7716AcB6f83ebF6268F8EECDA8892Ba1; // Horizen
        avalancheOptDVNs[1] = 0x962F502A63F5FBeB44DC9ab932122648E8352959; // LayerZero Labs
        avalancheOptDVNs[2] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind
        avalancheOptDVNs[3] = 0xbe57e9E7d9eB16B92C6383792aBe28D64a18c0F1; // Deutsche Telekom
        avalancheOptDVNs[4] = 0xcC49E6fca014c77E1Eb604351cc1E08C84511760; // Canary
        avalancheOptDVNs[5] = 0xE4193136B92bA91402313e95347c8e9FAD8d27d0; // Luganodes
        avalancheOptDVNs[6] = 0xE94aE34DfCC87A61836938641444080B98402c75; // P2P

        lane.remoteEid  = 30101;
        lane.remoteOApp = addr.addr("LZ_GOV_SENDER");
        lane.owner      = avalanche.addr("L2_AVALANCHE_LZ_GOV_RELAY");
        // Note: GovernanceOAppReceiver has no send config (receive-only)
        // Receive ULN config: 7 optional DVNs, threshold 4, no required DVNs
        lane.recvUln = LzUlnConfig({
            confirmations: 15,
            requiredDVNCount: 0,
            optionalDVNCount: 7,
            optionalDVNThreshold: 4,
            requiredDVNs: new address[](0),
            optionalDVNs: avalancheOptDVNs
        });
    }
}

/// @notice Minimal spell for testing governance relay on Avalanche.
contract AvalancheSetRateLimitsSpell {
    function execute(address oft, RateLimitConfig[] calldata inbound, RateLimitConfig[] calldata outbound) external {
        SkyOFTAdapterLike(oft).setRateLimits(inbound, outbound);
    }
}
