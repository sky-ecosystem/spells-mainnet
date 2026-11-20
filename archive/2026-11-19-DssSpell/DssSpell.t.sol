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

interface ERC4626FacetLike {
    function getDepositRateLimitKey(address token, address asset) external pure returns (bytes32);
}

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

    function testSafeHarborOwnership() public {
        _testSafeHarborOwnership();
    }

    function testSafeHarborUpdateSelectors() public {
        _testSafeHarborUpdateSelectors();
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

    function testAutoLineExecAfterEverySetIlkCall() public {
        _testAutoLineExecAfterEverySetIlkCall();
    }

    // Leave this test always enabled as it acts as a config test
    function testPSMs() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // No legacy PSMs remain in the ilk registry.
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
                bufUnits: 800_000_000,
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

    function testRemovedChainlogKeys() public { // add the `skipped` modifier to skip
        string[4] memory removedKeys = [
            "MCD_PSM_USDC_A",
            "MCD_JOIN_PSM_USDC_A",
            "MCD_CLIP_PSM_USDC_A",
            "MCD_CLIP_CALC_PSM_USDC_A"
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
        string[2] memory addedKeys = [
            "TEST_HALO_SUBPROXY",
            "TEST_HALO_STARGUARD"
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
        AllocatorIntegrationParams[1] memory params = [
            AllocatorIntegrationParams({
                ilk:            "ALLOCATOR-GROVE-A",
                pip:            addr.addr("PIP_ALLOCATOR"),
                registry:       addr.addr("ALLOCATOR_REGISTRY"),
                roles:          addr.addr("ALLOCATOR_ROLES"),
                buffer:         addr.addr("ALLOCATOR_GROVE_A_BUFFER"),
                vault:          addr.addr("ALLOCATOR_GROVE_A_VAULT"),
                allocatorProxy: addr.addr("GROVE_SUBPROXY"),
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
        bytes32[1] memory ilks = [
            bytes32("ALLOCATOR-GROVE-A")
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
        Authorization[2] memory newAuthorizations = [
            Authorization({ base: "STUSDS", ward: "STUSDS_MOM" }),
            Authorization({ base: "STUSDS_RATE_SETTER", ward: "STUSDS_MOM" })
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
        uint256 JAN_10_2027_14_01_47_UTC = 1799589707;

        uint256 spellCastTime = _getSpellCastTime();

        // Build expected new stream
        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  19,
            usr: addr.addr("REWARDS_DIST_LSSKY_SKY"),
            bgn: spellCastTime,
            clf: spellCastTime,
            fin: spellCastTime + 90 days,
            tau: 90 days,
            mgr: address(0),
            res: 1,
            tot: 104_897_852 * WAD,
            rxd: 0 // Amount already claimed
        });

        // For each yanked stream, provide Stream object and initialize the array with the current number of yanked streams
        YankedVestStream[] memory yankedStreams = new YankedVestStream[](1);
        yankedStreams[0] = YankedVestStream({
            id:  18,
            fin: JAN_10_2027_14_01_47_UTC,
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

    function testVestGrove() public skipped { // add the `skipped` modifier to skip
        uint256 spellCastTime = _getSpellCastTime();
        uint256 USDS_GROVE_VEST_TOTAL = 2_450_000_000 * WAD;
        uint256 USDS_GROVE_VEST_TAU   = 730 days;

        NewVestStream[] memory newStreams = new NewVestStream[](1);
        newStreams[0] = NewVestStream({
            id:  1,
            usr: addr.addr("REWARDS_DIST_USDS_GROVE"),
            bgn: spellCastTime - 7 days,
            clf: spellCastTime - 7 days,
            fin: spellCastTime - 7 days + USDS_GROVE_VEST_TAU,
            tau: USDS_GROVE_VEST_TAU,
            mgr: address(0),
            res: 1,
            tot: USDS_GROVE_VEST_TOTAL,
            rxd: (7 days * USDS_GROVE_VEST_TOTAL) / USDS_GROVE_VEST_TAU
        });

        YankedVestStream[] memory yankedStreams = new YankedVestStream[](0);

        _checkVest(
            VestInst({vest: vestGrove, gem: grove, name: "grove", isTransferrable: true}),
            newStreams,
            yankedStreams
        );
    }

    function testVestedRewardsDist() public { // add the `skipped` modifier to skip
        uint256 expectedVestIdBefore = 18;
        uint256 expectedVestIdAfter = 19;

        address rewardsDist = addr.addr("REWARDS_DIST_LSSKY_SKY");
        address stakingRewards = addr.addr("REWARDS_LSSKY_SKY");
        VestAbstract vest = VestAbstract(addr.addr("MCD_VEST_SKY_TREASURY"));

        uint256 vestIdBefore = VestedRewardsDistributionLike(rewardsDist).vestId();
        assertEq(vestIdBefore, expectedVestIdBefore, "TestError/rewards-dist-lssky-sky-invalid-vest-id-before");

        uint256 unpaidAmount = vest.unpaid(expectedVestIdBefore);
        assertTrue(unpaidAmount > 0, "TestError/rewards-dist-lssky-sky-unpaid-zero-early");

        _checkVestedRewardsDistributionRevertEdgeCase(rewardsDist);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        unpaidAmount = vest.unpaid(expectedVestIdBefore);
        assertEq(unpaidAmount, 0, "TestError/rewards-dist-lssky-sky-unpaid-not-cleared");

        // Check newly set vestId if updated
        uint256 vestIdAfter = VestedRewardsDistributionLike(rewardsDist).vestId();
        assertEq(vestIdAfter, expectedVestIdAfter, "TestError/rewards-dist-lssky-sky-invalid-vest-id-after");

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
        Payee[8] memory payees = [
            Payee(address(usds), addr.addr("SPARK_SUBPROXY"),                 4_188_099 ether), // Note: ether is only a keyword helper
            Payee(address(usds), addr.addr("GROVE_SUBPROXY"),                 2_170_826 ether), // Note: ether is only a keyword helper
            Payee(address(usds), addr.addr("KEEL_SUBPROXY"),                     34_034 ether), // Note: ether is only a keyword helper
            Payee(address(usds), addr.addr("OBEX_SUBPROXY"),                    205_907 ether), // Note: ether is only a keyword helper
            Payee(address(usds), addr.addr("SKYBASE_SUBPROXY"),                 145_439 ether), // Note: ether is only a keyword helper
            Payee(address(usds), addr.addr("OSERO_SUBPROXY"),                    42_396 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("DEMAND_SIDE_BUFFER_MULTISIG"),  1_000_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CORE_COUNCIL_BUDGET_MULTISIG"), 3_720_082 ether)  // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:           0  ether, // Note: ether is only a keyword helper
            mkr:           0  ether, // Note: ether is only a keyword helper
            usds: 11_506_783  ether, // Note: ether is only a keyword helper
            sky:           0  ether  // Note: ether is only a keyword helper
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

    function testBaseGovRelay() public { // add the `skipped` modifier to skip
        _setupRootDomain();
        baseDomain = new OptimismDomain(config, getRelativeChain("base"), rootDomain);
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
            "bafkreickfbtcslmburi6s4q6br6hn3j2cgdykf3ekv5i46r622vo3jzznm"
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

    function _testExpectedMscValues(AllocatorPayment[] memory payments, MscIlkValues[] memory expectedValues, uint256 expectedDaiVow) internal view {
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

    function testMonthlySettlementCycleInflows() public { // add the `skipped` modifier to skip
        AllocatorPayment[] memory payments = new AllocatorPayment[](4);
        payments[0] = AllocatorPayment(addr.addr("ALLOCATOR_SPARK_A_VAULT"), 14_048_690 * WAD);
        payments[1] = AllocatorPayment(addr.addr("ALLOCATOR_BLOOM_A_VAULT"),  8_866_792 * WAD);
        payments[2] = AllocatorPayment(addr.addr("ALLOCATOR_OBEX_A_VAULT"),   1_463_217 * WAD);
        payments[3] = AllocatorPayment(addr.addr("ALLOCATOR_PRYSM_A_VAULT"),     15_812 * WAD);
        uint256 expectedTotalAmount = 24_394_511 * WAD;

        MscIlkValues[] memory expectedValues = new MscIlkValues[](payments.length);
        uint256 totalDtab = 0;
        uint256 totalPayments = 0;

        _vote(address(spell));
        spell.schedule();
        vm.warp(spell.nextCastTime());

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

        // Include the core vault fees credited to the Vow during this cast.
        bytes32[5] memory ilks = [bytes32("ETH-A"), "ETH-B", "ETH-C", "WSTETH-A", "WSTETH-B"];
        for (uint256 i = 0; i < ilks.length; i++) {
            jug.drip(ilks[i]);
        }
        uint256 expectedDaiVow = vat.dai(address(vow)) + totalDtab;

        spell.cast();
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Test with MCD_JUG.drip() having been called in the same block
        _testExpectedMscValues(payments, expectedValues, expectedDaiVow);

        vm.revertToStateAndDelete(before);

        spell.cast();
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
                // Insert Prime Agent StarGuards Chainlog key
                starGuardKey: "SPARK_STARGUARD",
                // Insert Prime Agent spell address
                addr: 0x0703EBA65Ff30c245f739087B4c5280e9e4dBD50,
                // Insert Prime Agent spell codehash
                codehash: 0x0a88e3ab7468f13e69d3e49699ccd8463dedc9609ea097e23c19e6106810e6c8,
                // Set to true if the Prime Agent spell is executed directly from core spell
                directExecutionEnabled: false
            }),
            PrimeAgentSpell({
                // Insert Prime Agent StarGuards Chainlog key
                starGuardKey: "GROVE_STARGUARD",
                // Insert Prime Agent spell address
                addr: 0x1a74cC68A37f24367914fAc1915cC604CB3D72AF,
                // Insert Prime Agent spell codehash
                codehash: 0x45f2833db32128803bd3ce7dc8fa9837a38db7791cacd99ac1c90598d0a70bc9,
                // Set to true if the Prime Agent spell is executed directly from core spell
                directExecutionEnabled: false
            }),
            PrimeAgentSpell({
                // Insert Prime Agent StarGuards Chainlog key
                starGuardKey: "OSERO_STARGUARD",
                // Insert Prime Agent spell address
                addr: 0xC1989b5c81eA2bC4A6Abda0e73e3E3C48D500d05,
                // Insert Prime Agent spell codehash
                codehash: 0xd99ef190c8ebdfbe3ddd67e84a2d63243b0f354e4841928a8bc6869a4055d77b,
                // Set to true if the Prime Agent spell is executed directly from core spell
                directExecutionEnabled: false
            })
        ];

        for (uint256 i = 0; i < primeAgentSpells.length; i++) {
            _testStarGuardExecution({
                starGuardKey: primeAgentSpells[i].starGuardKey,
                primeAgentSpell: primeAgentSpells[i].addr,
                primeAgentSpellHash: primeAgentSpells[i].codehash,
                directExecutionEnabled: primeAgentSpells[i].directExecutionEnabled
            });
        }
    }

    struct StarguardValues {
        address starGuard;
        address subProxy;
    }

    function testStarGuardInitialization() public { // add the `skipped` modifier to skip
        StarguardValues[1] memory initializedStarGuards = [
            StarguardValues({
                starGuard: addr.addr("TEST_HALO_STARGUARD"), // Insert StarGuard address
                subProxy: addr.addr("TEST_HALO_SUBPROXY")    // Insert SubProxy address
            })
        ];

        for (uint256 i = 0; i < initializedStarGuards.length; i++) {
            address starGuard = initializedStarGuards[i].starGuard;
            address subProxy = initializedStarGuards[i].subProxy;

            _testStarGuardInitialization(starGuard, subProxy);
        }
    }

    // SPELL-SPECIFIC TESTS GO BELOW

    function testBurnSky() public {
        uint256 skyTotalSupplyBefore     = sky.totalSupply();
        uint256 skyTreasuryBalanceBefore = sky.balanceOf(address(pauseProxy));

        // Note: `updateFarmVest` distributes the accrued amount of the previous LSSKY->SKY vest
        // out of the treasury (the vest czar) before yanking it.
        VestedRewardsDistributionLike dist = VestedRewardsDistributionLike(addr.addr("REWARDS_DIST_LSSKY_SKY"));
        VestAbstract vestSky      = VestAbstract(dist.dssVest());
        uint256 prevVestId        = dist.vestId();
        uint256 prevVestRxdBefore = vestSky.rxd(prevVestId);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        uint256 distributed = vestSky.rxd(prevVestId) - prevVestRxdBefore;

        assertEq(
            sky.totalSupply(),
            skyTotalSupplyBefore - 7_770_211 ether,
            "TestError/invalid-total-supply"
        );
        assertEq(
            sky.balanceOf(address(pauseProxy)),
            skyTreasuryBalanceBefore - 7_770_211 ether - distributed,
            "TestError/invalid-treasury-balance"
        );
    }

    function testCoreVaultDebtCeilingChanges() public {
        bytes32[5] memory ilks = [bytes32("ETH-A"), "ETH-B", "ETH-C", "WSTETH-A", "WSTETH-B"];
        uint256[5] memory beforeArts;
        uint256[5] memory expectedRates;

        _vote(address(spell));
        spell.schedule();
        // Delay the cast to exercise fees accrued since the last drip.
        vm.warp(spell.nextCastTime() + 7 days);

        uint256 preLine = vat.Line();
        uint256 correction;
        uint256 before = vm.snapshotState();

        // Calculate the expected reduction with fees accrued through the cast timestamp.
        {
            uint256 correctionBeforeDrip;
            for (uint256 i = 0; i < ilks.length; i++) {
                uint256 rate;
                uint256 line;
                (beforeArts[i], rate,, line,) = vat.ilks(ilks[i]);
                uint256 debt = beforeArts[i] * rate;
                correctionBeforeDrip += line > debt ? line - debt : 0;

                expectedRates[i] = jug.drip(ilks[i]);
                debt = beforeArts[i] * expectedRates[i];
                correction += line > debt ? line - debt : 0;
            }
            assertLt(correction, correctionBeforeDrip, "TestError/fixture-did-not-accrue");
        }

        // Test with MCD_JUG.drip() having been called in the same block.
        spell.cast();
        assertTrue(spell.done(), "TestError/spell-not-done");
        assertEq(vat.Line(), preLine - correction, "TestError/global-line-adjustment");

        for (uint256 i = 0; i < ilks.length; i++) {
            (uint256 Art, uint256 rate,,,) = vat.ilks(ilks[i]);
            assertEq(Art, beforeArts[i], "TestError/principal-changed");
            assertEq(rate, expectedRates[i], "TestError/rate-changed");
            (, uint256 rho) = jug.ilks(ilks[i]);
            assertEq(rho, block.timestamp, "TestError/rho-not-updated");
        }
        uint256 debtAfter = vat.debt();
        uint256 daiVowAfter = vat.dai(address(vow));

        vm.revertToStateAndDelete(before);

        // Test without prior MCD_JUG.drip() at the same delayed cast timestamp.
        spell.cast();
        assertTrue(spell.done(), "TestError/spell-not-done");
        assertEq(vat.Line(), preLine - correction, "TestError/global-line-adjustment");
        assertEq(vat.debt(), debtAfter, "TestError/debt-depends-on-prior-drip");
        assertEq(vat.dai(address(vow)), daiVowAfter, "TestError/vow-dai-depends-on-prior-drip");

        for (uint256 i = 0; i < ilks.length; i++) {
            (uint256 Art, uint256 rate,,,) = vat.ilks(ilks[i]);
            assertEq(Art, beforeArts[i], "TestError/principal-changed");
            assertEq(rate, expectedRates[i], "TestError/rate-not-updated");
            (, uint256 rho) = jug.ilks(ilks[i]);
            assertEq(rho, block.timestamp, "TestError/rho-not-updated");
        }
    }

    function testLineAdjustmentBoundaries() public {
        bytes32[5] memory ilks = [bytes32("ETH-A"), "ETH-B", "ETH-C", "WSTETH-A", "WSTETH-B"];
        uint256[5] memory beforeArts;
        uint256[5] memory beforeRates;

        _vote(address(spell));
        spell.schedule();
        vm.warp(spell.nextCastTime());

        // Give ETH-A zero debt to exercise removal of its entire unused capacity.
        stdstore.target(address(vat)).sig("ilks(bytes32)").with_key(bytes32("ETH-A")).depth(0).checked_write(uint256(0));
        // Set the boundaries using debt accrued through the cast timestamp.
        for (uint256 i = 0; i < ilks.length; i++) {
            jug.drip(ilks[i]);
            (beforeArts[i], beforeRates[i],,,) = vat.ilks(ilks[i]);
            if (i != 0) assertGt(beforeArts[i], 0, "TestError/fixture-no-debt");
        }
        // Capacities are in raw RAD units to detect rounding to whole USDS.
        uint256 zeroDebtCapacity = 29;
        uint256 positiveDebtCapacity = 17;
        uint256[5] memory lines = [
            zeroDebtCapacity,                                      // ETH-A: zero debt, positive ceiling.
            beforeArts[1] * beforeRates[1],                         // ETH-B: debt equals ceiling.
            beforeArts[2] * beforeRates[2] - 1,                     // ETH-C: debt exceeds ceiling by one RAD unit.
            uint256(0),                                           // WSTETH-A: zero ceiling, positive debt.
            beforeArts[4] * beforeRates[4] + positiveDebtCapacity   // WSTETH-B: ceiling exceeds debt.
        ];
        vm.startPrank(pauseProxy);
        for (uint256 i = 0; i < ilks.length; i++) {
            vat.file(ilks[i], "line", lines[i]);
        }
        vm.stopPrank();
        uint256 preLine = vat.Line();

        spell.cast();
        assertTrue(spell.done(), "TestError/spell-not-done");
        assertEq(vat.Line(), preLine - zeroDebtCapacity - positiveDebtCapacity, "TestError/global-line-boundaries");

        for (uint256 i = 0; i < ilks.length; i++) {
            (uint256 Art, uint256 rate,, uint256 line,) = vat.ilks(ilks[i]);
            assertEq(Art, beforeArts[i], "TestError/principal-changed");
            assertEq(rate, beforeRates[i], "TestError/rate-changed");
            assertEq(line, 0, "TestError/line-not-zero");
        }
    }

    function testOffboardPsms() public {
        bytes32 ilk = "PSM-USDC-A";
        address psm = addr.addr("MCD_PSM_USDC_A");
        address join = addr.addr("MCD_JOIN_PSM_USDC_A");
        address clip = addr.addr("MCD_CLIP_PSM_USDC_A");
        GemAbstract token = GemAbstract(addr.addr("USDC"));
        address recipient = wallets.addr("CORE_COUNCIL_BUDGET_MULTISIG");
        uint256 amount = 99_328_577; // 99.328577 USDC, in native six-decimal units.

        {
            (uint256 ink, uint256 art) = vat.urns(ilk, psm);
            (uint256 Art,,, uint256 line,) = vat.ilks(ilk);
            assertEq(ink, 0, "testOffboardPsms/ink-not-zero-before");
            assertEq(art, 0, "testOffboardPsms/art-not-zero-before");
            assertEq(Art, 0, "testOffboardPsms/Art-not-zero-before");
            assertEq(line, 0, "testOffboardPsms/line-not-zero-before");
        }
        assertEq(LineMomLike(address(lineMom)).ilks(ilk), 1, "testOffboardPsms/not-in-line-mom-before");
        assertEq(reg.join(ilk), join, "testOffboardPsms/not-in-ilk-registry-before");
        assertEq(GemJoinAbstract(join).live(), 1, "testOffboardPsms/join-not-live-before");
        assertEq(GemJoinAbstract(join).gem(), address(token), "testOffboardPsms/wrong-gem");
        assertEq(GemJoinAbstract(join).dec(), 6, "testOffboardPsms/wrong-decimals");
        assertEq(vat.wards(join), 1, "testOffboardPsms/join-not-authed-on-vat-before");
        assertEq(vat.wards(clip), 1, "testOffboardPsms/clip-not-authed-on-vat-before");
        assertEq(dog.wards(clip), 1, "testOffboardPsms/clip-not-authed-on-dog-before");

        // Recovery is a fixed amount: an extra donation must remain in the Join.
        _giveTokens(address(token), 1_000_000);
        assertTrue(token.transfer(join, 1_000_000));
        vm.prank(pauseProxy);
        vat.slip(ilk, pauseProxy, int256(17 * WAD));
        uint256 gemBefore = vat.gem(ilk, pauseProxy);
        uint256 joinBalanceBefore = token.balanceOf(join);
        uint256 recipientBalanceBefore = token.balanceOf(recipient);
        uint256 daiBalanceBefore = dai.balanceOf(join);
        assertGe(joinBalanceBefore, amount + 1_000_000, "testOffboardPsms/insufficient-recovery-custody");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(token.balanceOf(join), joinBalanceBefore - amount, "testOffboardPsms/invalid-join-balance");
        assertEq(token.balanceOf(recipient), recipientBalanceBefore + amount, "testOffboardPsms/invalid-recipient-balance");
        assertEq(vat.gem(ilk, pauseProxy), gemBefore, "testOffboardPsms/free-gem-changed");
        assertEq(dai.balanceOf(join), daiBalanceBefore, "testOffboardPsms/dai-balance-changed");
        {
            (uint256 ink, uint256 art) = vat.urns(ilk, psm);
            (uint256 Art,,,,) = vat.ilks(ilk);
            assertEq(ink, 0, "testOffboardPsms/ink-not-zero-after");
            assertEq(art, 0, "testOffboardPsms/art-not-zero-after");
            assertEq(Art, 0, "testOffboardPsms/Art-not-zero-after");
        }

        // Removed from ILK_REGISTRY and LINE_MOM; permissionless re-add is impossible.
        assertEq(reg.join(ilk), address(0), "testOffboardPsms/still-in-ilk-registry");
        assertEq(LineMomLike(address(lineMom)).ilks(ilk), 0, "testOffboardPsms/still-in-line-mom");
        vm.expectRevert("IlkRegistry/adapter-not-authorized");
        reg.add(join);

        // Join caged and module permissions revoked; governance administration remains.
        assertEq(GemJoinAbstract(join).live(), 0, "testOffboardPsms/join-not-caged");
        assertEq(vat.wards(join), 0, "testOffboardPsms/join-still-authed-on-vat");
        assertEq(vat.wards(clip), 0, "testOffboardPsms/clip-still-authed-on-vat");
        assertEq(dog.wards(clip), 0, "testOffboardPsms/clip-still-authed-on-dog");
        assertEq(GemJoinAbstract(join).wards(pauseProxy), 1, "testOffboardPsms/join-governance-auth-removed");
        assertEq(WardsAbstract(clip).wards(pauseProxy), 1, "testOffboardPsms/clip-governance-auth-removed");
        assertEq(WardsAbstract(psm).wards(pauseProxy), 1, "testOffboardPsms/psm-governance-auth-removed");
        assertEq(vat.wards(pauseProxy), 1, "testOffboardPsms/vat-governance-auth-removed");
    }

    function testPsmUsdcRecoveryFailure() public {
        bytes32 ilk = "PSM-USDC-A";
        address join = addr.addr("MCD_JOIN_PSM_USDC_A");
        address clip = addr.addr("MCD_CLIP_PSM_USDC_A");
        GemAbstract token = GemAbstract(addr.addr("USDC"));
        address recipient = wallets.addr("CORE_COUNCIL_BUDGET_MULTISIG");
        uint256 amount = 99_328_577;

        // Test-only custody reduction forces the actual token transfer to revert inside exit.
        // A nonzero existing free-gem balance must survive the catch compensation.
        uint256 withdrawal = token.balanceOf(join) - (amount - 1);
        assertGt(withdrawal, 0, "testPsmUsdcRecoveryFailure/invalid-custody-fixture");
        vm.prank(join);
        assertTrue(token.transfer(address(this), withdrawal));
        vm.prank(pauseProxy);
        vat.slip(ilk, pauseProxy, int256(17 * WAD));
        uint256 gemBefore = vat.gem(ilk, pauseProxy);
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        _vote(address(spell));
        vm.expectCall(address(token), abi.encodeWithSignature("transfer(address,uint256)", recipient, amount));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(token.balanceOf(join), amount - 1, "testPsmUsdcRecoveryFailure/custody-changed");
        assertEq(token.balanceOf(recipient), recipientBalanceBefore, "testPsmUsdcRecoveryFailure/recipient-paid");
        assertEq(vat.gem(ilk, pauseProxy), gemBefore, "testPsmUsdcRecoveryFailure/slip-not-compensated");
        // The caught recovery failure must not skip the remaining offboarding actions.
        assertEq(reg.join(ilk), address(0), "testPsmUsdcRecoveryFailure/still-in-ilk-registry");
        assertEq(LineMomLike(address(lineMom)).ilks(ilk), 0, "testPsmUsdcRecoveryFailure/still-in-line-mom");
        assertEq(GemJoinAbstract(join).live(), 0, "testPsmUsdcRecoveryFailure/join-not-caged");
        assertEq(vat.wards(join), 0, "testPsmUsdcRecoveryFailure/join-still-authed-on-vat");
        assertEq(vat.wards(clip), 0, "testPsmUsdcRecoveryFailure/clip-still-authed-on-vat");
        assertEq(dog.wards(clip), 0, "testPsmUsdcRecoveryFailure/clip-still-authed-on-dog");
    }

    function _baseBeaconPasParams() internal returns (OpL2BeaconPasParams memory p) {
        uint256 l1Fork = vm.activeFork();
        _setupRootDomain();
        baseDomain = new OptimismDomain(config, getRelativeChain("base"), rootDomain);
        vm.makePersistent(address(addr), address(base), address(wallets));

        p.domain        = baseDomain;
        p.l1GovRelay    = addr.addr("BASE_GOV_RELAY");
        p.l2GovRelay    = base.addr("L2_GOV_RELAY");
        p.l2Multicall   = base.addr("L2_MULTICALL_SPELL");
        p.l2Beacon      = base.addr("L2_PAU_BEACON");
        p.pas           = base.addr("L2_PAS_STATE");
        p.cBeam         = wallets.addr("OSERO_PAS_CBEAM");
        p.rateLimits    = base.addr("BASE_OSERO_RATE_LIMITS");
        p.controller    = base.addr("BASE_OSERO_CONTROLLER");
        p.integrationId = "ERC4626_FACET";

        p.preservedIntegrationIds    = new bytes32[](1);
        p.preservedIntegrationIds[0] = "CCTP_FACET";

        p.deadlineDuration   = 7 days;
        p.relayDelay         = 60 seconds;
        p.minGas             = 1_000_000;
        p.hop                = 0;
        p.maxChange          = 0;
        p.effectiveHop       = 16 hours;
        p.effectiveMaxChange = 1.2e18;
        p.initialMaxAmount   = 0;
        p.initialSlope       = 0;

        baseDomain.selectFork();
        // Get the USDC deposit rate-limit key for Osero's vault from the ERC4626 Facet.
        p.initialRateLimitKey = ERC4626FacetLike(base.addr("L2_ERC4626_FACET")).getDepositRateLimitKey(
            base.addr("BASE_OSERO_USDC_VAULT"),
            base.addr("L2_USDC")
        );
        // Return to the original fork so the Core cast uses the requested Ethereum block.
        vm.selectFork(l1Fork);

        // Copy the L1 integration config and replace only its facet.
        p.integrationConfig = BeaconTestLike(addr.addr("PAU_BEACON")).getConfig(p.integrationId);
        p.integrationConfig.facet = base.addr("L2_ERC4626_FACET");

        // Build the expected six-call batch independently of the emitted message.
        p.calls = new L2MulticallTestLike.Call[](6);
        p.calls[0] = L2MulticallTestLike.Call(
            p.l2Beacon,
            abi.encodeCall(BeaconTestLike.setIntegration, (p.integrationId, p.integrationConfig))
        );
        p.calls[1] = L2MulticallTestLike.Call(p.pas, abi.encodeCall(PASBeamStateLike.addCBeam, (p.cBeam)));
        p.calls[2] = L2MulticallTestLike.Call(p.pas, abi.encodeCall(PASBeamStateLike.addRateLimits, (p.rateLimits)));
        p.calls[3] = L2MulticallTestLike.Call(
            p.pas,
            abi.encodeCall(PASBeamStateLike.setCBeamForRateLimits, (p.rateLimits, p.cBeam))
        );
        p.calls[4] = L2MulticallTestLike.Call(p.pas, abi.encodeCall(PASBeamStateLike.addController, (p.controller)));
        p.calls[5] = L2MulticallTestLike.Call(
            p.pas,
            abi.encodeCall(PASBeamStateLike.setCBeamForController, (p.controller, p.cBeam))
        );
    }

    function testBaseSpellExecution() public {
        _testOpL2BeaconPasExecution(_baseBeaconPasParams());
    }

    function testBaseSpellAfterDeadline() public {
        _testOpL2BeaconPasAfterDeadline(_baseBeaconPasParams());
    }

    function testBaseSpellRollback() public {
        _testOpL2BeaconPasRollback(_baseBeaconPasParams());
    }
}
