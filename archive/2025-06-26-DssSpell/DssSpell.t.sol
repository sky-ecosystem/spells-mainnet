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
import { DssExec } from "dss-exec-lib/DssExec.sol";

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

interface ERC20Like {
    function allowance(address, address) external view returns (uint256);
}

interface DssVestLike {
    function cap() external view returns (uint256);
    function czar() external view returns (address);
    function gem() external view returns (address);
    function awards(uint256) external view returns (address, uint48, uint48, uint48, address, uint8, uint128);
}

interface SequencerLike {
    function getMaster() external view returns (bytes32);
    function hasJob(address job) external view returns (bool);
}

interface VestedRewardsDistributionJobLike {
    function has(address) external view returns (bool);
    function intervals(address) external view returns (uint256);
    function workable(bytes32) external returns (bool, bytes memory);
    function work(bytes32, bytes memory) external;
}

interface VestedRewardsDistributionLike {
    function dssVest() external view returns (address);
    function stakingRewards() external view returns (address);
    function gem() external view returns (address);
    function wards(address) external view returns (uint256);
    function vestId() external view returns (uint256);
    function lastDistributedAt() external view returns (uint256);
}

interface WardsLike {
    function wards(address) external view returns (uint256);
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

    // NOTE: skipped due to the custom min ETA logic in the current spell
    function testNextCastTime() public skipped {
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

    function testRemovedChainlogKeys() public { // add the `skipped` modifier to skip
        string[1] memory removedKeys = [
            "MKR_SKY_LEGACY"
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
        string[6] memory addedKeys = [
            "SPK",
            "MCD_VEST_SPK_TREASURY",
            "REWARDS_USDS_SPK",
            "REWARDS_DIST_USDS_SPK",
            "REWARDS_LSSKY_SPK",
            "REWARDS_DIST_LSSKY_SPK"
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

    function testIlkClipper() public skipped { // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

       _checkIlkClipper(
            "RETH-A",
            GemJoinAbstract(addr.addr("MCD_JOIN_RETH_A")),
            ClipAbstract(addr.addr("MCD_CLIP_RETH_A")),
            addr.addr("MCD_CLIP_CALC_RETH_A"),
            OsmAbstract(addr.addr("PIP_RETH")),
            1_000 * WAD
        );
    }

    function testLockstakeIlkIntegration() public { // add the `skipped` modifier to skip
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        _checkLockstakeIlkIntegration(
            LockstakeIlkParams({
                ilk:    "LSEV2-SKY-A",
                fee:    0,
                pip:    addr.addr("PIP_SKY"),
                lssky:  addr.addr("LOCKSTAKE_SKY"),
                engine: addr.addr("LOCKSTAKE_ENGINE"),
                clip:   addr.addr("LOCKSTAKE_CLIP"),
                calc:   addr.addr("LOCKSTAKE_CLIP_CALC"),
                farm:   addr.addr("REWARDS_LSSKY_SPK"),
                rToken: addr.addr("SPK"),
                rDistr: addr.addr("REWARDS_DIST_LSSKY_SPK"),
                rDur:   7 days
            })
        );
    }

    function testAllocatorIntegration() public skipped { // add the `skipped` modifier to skip
        AllocatorIntegrationParams memory p = AllocatorIntegrationParams({
            ilk:            "ALLOCATOR-BLOOM-A",
            pip:            addr.addr("PIP_ALLOCATOR"),
            registry:       addr.addr("ALLOCATOR_REGISTRY"),
            roles:          addr.addr("ALLOCATOR_ROLES"),
            buffer:         addr.addr("ALLOCATOR_BLOOM_A_BUFFER"),
            vault:          addr.addr("ALLOCATOR_BLOOM_A_VAULT"),
            allocatorProxy: addr.addr("ALLOCATOR_BLOOM_A_SUBPROXY")
        });

        // Sanity checks
        require(AllocatorVaultLike(p.vault).ilk()      == p.ilk,                 "AllocatorInit/vault-ilk-mismatch");
        require(AllocatorVaultLike(p.vault).roles()    == p.roles,               "AllocatorInit/vault-roles-mismatch");
        require(AllocatorVaultLike(p.vault).buffer()   == p.buffer,              "AllocatorInit/vault-buffer-mismatch");
        require(AllocatorVaultLike(p.vault).vat()      == address(vat),          "AllocatorInit/vault-vat-mismatch");
        require(AllocatorVaultLike(p.vault).usdsJoin() == address(usdsJoin),     "AllocatorInit/vault-usds-join-mismatch");

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
        vm.prank(addr.addr("ALLOCATOR_BLOOM_A_SUBPROXY"));
        AllocatorVaultLike(p.vault).draw(1_000 * WAD);
        assertEq(usds.balanceOf(p.buffer), 1_000 * WAD);

        vm.warp(block.timestamp + 1);
        jug.drip(p.ilk);

        vm.prank(addr.addr("ALLOCATOR_BLOOM_A_SUBPROXY"));
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
        Authorization[1] memory newAuthorizations = [
            Authorization({ base: "MCD_VAT",          ward: "MCD_VEST_USDS" })
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

        // For each new stream, provide Stream object
        // and initialize the array with the corrent number of new streams
        VestStream[] memory streams = new VestStream[](1);
        streams[0] = VestStream({
            id:  39,
            usr: wallets.addr("JANSKY"),
            bgn: OCT_01_2024,
            clf: OCT_01_2024,
            fin: JAN_31_2025,
            tau: 123 days - 1,
            mgr: address(0),
            res: 1,
            tot: 168_000 * WAD,
            rxd: 0
        });

        _checkVest(
            VestInst({vest: vestDai, gem: GemAbstract(address(dai)), name: "dai", isTransferrable: false}),
            streams
        );
    }

    function testVestMkr() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 OCT_01_2024 = 1727740800;
        uint256 JAN_31_2025 = 1738367999;

        // For each new stream, provide Stream object
        // and initialize the array with the corrent number of new streams
        VestStream[] memory streams = new VestStream[](1);
        streams[0] = VestStream({
            id:  45,
            usr: wallets.addr("JANSKY"),
            bgn: OCT_01_2024,
            clf: OCT_01_2024,
            fin: JAN_31_2025,
            tau: 123 days - 1,
            mgr: address(0),
            res: 1,
            tot: 72 * WAD,
            rxd: 0
        });

        _checkVest(
            VestInst({vest: vestMkr, gem: GemAbstract(address(mkr)), name: "mkr", isTransferrable: true}),
            streams
        );
    }

    function testVestUsds() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 FEB_01_2025 = 1738368000;
        uint256 DEC_31_2025 = 1767225599;

        // For each new stream, provide Stream object
        // and initialize the array with the corrent number of new streams
        VestStream[] memory streams = new VestStream[](3);
        streams[0] = VestStream({
            id:  1,
            usr: wallets.addr("VOTEWIZARD"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0
        });
        streams[1] = VestStream({
            id:  2,
            usr: wallets.addr("JANSKY"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0
        });
        streams[2] = VestStream({
            id:  3,
            usr: wallets.addr("ECOSYSTEM_FACILITATOR"),
            bgn: FEB_01_2025,
            clf: FEB_01_2025,
            fin: DEC_31_2025,
            tau: 334 days - 1,
            mgr: address(0),
            res: 1,
            tot: 462_000 * WAD,
            rxd: 0
        });

        _checkVest(
            VestInst({vest: vestUsds, gem: usds, name: "usds", isTransferrable: false}),
            streams
        );
    }

    function testVestSky() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        // uint256 FEB_01_2025 = 1738368000;

        VestStream[] memory streams = new VestStream[](1);

        // This stream is configured in relative to the spell casting time.
        {

            uint256 before = vm.snapshotState();
            _vote(address(spell));
            spell.schedule();
            vm.warp(spell.nextCastTime());

            // For each new stream, provide Stream object
            // and initialize the array with the corrent number of new streams
            streams[0] = VestStream({
                id:  4,
                usr: addr.addr("REWARDS_DIST_USDS_SKY"),
                bgn: block.timestamp,
                clf: block.timestamp,
                fin: block.timestamp + uint256(182 days),
                tau: 182 days,
                mgr: address(0),
                res: 1,
                tot: 137_500_000 * WAD,
                rxd: 0
            });

            vm.revertToStateAndDelete(before);
        }

        _checkVest(
            VestInst({vest: vestSky, gem: sky, name: "sky", isTransferrable: true}),
            streams
        );
    }

    function testVestSkyMint() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        // uint256 DEC_01_2023 = 1701385200;

        // For each new stream, provide Stream object
        // and initialize the array with the corrent number of new streams
        VestStream[] memory streams = new VestStream[](1);

        // This stream is configured in relative to the spell casting time.
        {
            uint256 before = vm.snapshotState();
            _vote(address(spell));
            spell.schedule();
            vm.warp(spell.nextCastTime());

            streams[0] = VestStream({
                id:  2,
                usr: addr.addr("REWARDS_DIST_USDS_SKY"),
                bgn: block.timestamp,
                clf: block.timestamp,
                fin: block.timestamp + 15_724_800 seconds,
                tau: 15_724_800 seconds,
                mgr: address(0),
                res: 1,
                tot: 160_000_000 * WAD,
                rxd: 0
            });

            vm.revertToStateAndDelete(before);
        }

        _checkVest(
            VestInst({vest: vestSkyMint, gem: sky, name: "skyMint", isTransferrable: false}),
            streams
        );
    }

    function testVestSpk() public { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 beforeVote = vm.snapshotState();
        _vote(address(spell));
        spell.schedule();

        uint256 CAST_TIME_MINUS_7_DAYS = spell.nextCastTime() - 7 days;
        uint256 BGN_PLUS_730_DAYS = CAST_TIME_MINUS_7_DAYS + 730 days;

        vm.revertToStateAndDelete(beforeVote);

        // For each new stream, provide Stream object
        // and initialize the array with the corrent number of new streams
        VestStream[] memory streams = new VestStream[](2);
        streams[0] = VestStream({
            id:  1,
            usr: addr.addr("REWARDS_DIST_USDS_SPK"),
            bgn: CAST_TIME_MINUS_7_DAYS,
            clf: CAST_TIME_MINUS_7_DAYS,
            fin: BGN_PLUS_730_DAYS,
            tau: 730 days,
            mgr: address(0),
            res: 1,
            tot: 2_275_000_000 * WAD,
            rxd: 7 days * 2_275_000_000 * WAD / 730 days
        });
        streams[1] = VestStream({
            id:  2,
            usr: addr.addr("REWARDS_DIST_LSSKY_SPK"),
            bgn: CAST_TIME_MINUS_7_DAYS,
            clf: CAST_TIME_MINUS_7_DAYS,
            fin: BGN_PLUS_730_DAYS,
            tau: 730 days,
            mgr: address(0),
            res: 1,
            tot: 975_000_000 * WAD,
            rxd: 7 days * 975_000_000 * WAD / 730 days
        });

        _checkVest(
            VestInst({vest: vestSpk, gem: spk, name: "spk", isTransferrable: true}),
            streams
        );
    }

    struct Yank {
        uint256 streamId;
        address addr;
        uint256 finPlanned;
    }

    function testYankDAI() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 FEB_29_2024 = 1709251199;
        uint256 MAR_31_2024 = 1711929599;

        // For each yanked stream, provide Yank object with:
        //   the stream id
        //   the address of the stream
        //   the planned fin of the stream (via variable defined above)
        // Initialize the array with the corrent number of yanks
        Yank[2] memory yanks = [
            Yank(20, wallets.addr("BA_LABS"), FEB_29_2024),
            Yank(21, wallets.addr("BA_LABS"), MAR_31_2024)
        ];

        // Test stream id matches `addr` and `fin`
        VestAbstract vest = VestAbstract(addr.addr("MCD_VEST_DAI")); // or "MCD_VEST_DAI_LEGACY"
        for (uint256 i = 0; i < yanks.length; i++) {
            assertEq(vest.usr(yanks[i].streamId), yanks[i].addr, "testYankDAI/unexpected-address");
            assertEq(vest.fin(yanks[i].streamId), yanks[i].finPlanned, "testYankDAI/unexpected-fin-date");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
        for (uint256 i = 0; i < yanks.length; i++) {
            // Test stream.fin is set to the current block after the spell
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankDAI/steam-not-yanked");
        }
    }

    function testYankMKR() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 MAR_31_2024 = 1711929599;

        // For each yanked stream, provide Yank object with:
        //   the stream id
        //   the address of the stream
        //   the planned fin of the stream (via variable defined above)
        // Initialize the array with the corrent number of yanks
        Yank[1] memory yanks = [
            Yank(35, wallets.addr("BA_LABS"), MAR_31_2024)
        ];

        // Test stream id matches `addr` and `fin`
        VestAbstract vestTreasury = VestAbstract(addr.addr("MCD_VEST_MKR_TREASURY"));
        for (uint256 i = 0; i < yanks.length; i++) {
            assertEq(vestTreasury.usr(yanks[i].streamId), yanks[i].addr, "testYankMKR/unexpected-address");
            assertEq(vestTreasury.fin(yanks[i].streamId), yanks[i].finPlanned, "testYankMKR/unexpected-fin-date");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
        for (uint256 i = 0; i < yanks.length; i++) {
            // Test stream.fin is set to the current block after the spell
            assertEq(vestTreasury.fin(yanks[i].streamId), block.timestamp, "testYankMKR/steam-not-yanked");

            // Give admin powers to test contract address and make the vesting unrestricted for testing
            GodMode.setWard(address(vestTreasury), address(this), 1);

            // Test vest can still be called, making stream "invalid" and not changing `fin` timestamp
            vestTreasury.unrestrict(yanks[i].streamId);
            vestTreasury.vest(yanks[i].streamId);
            assertTrue(!vestTreasury.valid(yanks[i].streamId));
            assertEq(vestTreasury.fin(yanks[i].streamId), block.timestamp, "testYankMKR/steam-fin-changed");
        }
    }

    function testYankSkyMint() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 OCT_20_2025 = 1760968859;

        // For each yanked stream, provide Yank object with:
        //   the stream id
        //   the address of the stream
        //   the planned fin of the stream (via variable defined above)
        // Initialize the array with the corrent number of yanks
        Yank[1] memory yanks = [
            Yank(2, chainLog.getAddress("REWARDS_DIST_USDS_SKY"), OCT_20_2025)
        ];

        // Test stream id matches `addr` and `fin`
        VestAbstract vest = VestAbstract(addr.addr("MCD_VEST_SKY"));
        for (uint256 i = 0; i < yanks.length; i++) {
            assertEq(vest.usr(yanks[i].streamId), yanks[i].addr, "testYankSkyMint/unexpected-address");
            assertEq(vest.fin(yanks[i].streamId), yanks[i].finPlanned, "testYankSkyMint/unexpected-fin-date");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
        for (uint256 i = 0; i < yanks.length; i++) {
            // Test stream.fin is set to the current block after the spell
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSkyMint/steam-not-yanked");

            // Give admin powers to test contract address and make the vesting unrestricted for testing
            GodMode.setWard(address(vest), address(this), 1);

            // Test vest can still be called, making stream "invalid" and not changing `fin` timestamp
            vest.unrestrict(yanks[i].streamId);
            vest.vest(yanks[i].streamId);
            assertTrue(!vest.valid(yanks[i].streamId));
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSkyMint/steam-fin-changed");
        }
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

    // Note: Skipping this test in favor of `testPayments_ignoreBurnsAndConversion` for this spell.
    function testPayments() public skipped { // add the `skipped` modifier to skip
        // Note: set to true when there are additional DAI/USDS operations (e.g. surplus buffer sweeps, SubDAO draw-downs) besides direct transfers
        bool ignoreTotalSupplyDaiUsds = true; // Note: Payments are being made through DaiUsds

        // For each payment, create a Payee object with:
        //    the address of the transferred token,
        //    the destination address,
        //    the amount to be paid
        // Initialize the array with the number of payees
        Payee[11] memory payees = [
            Payee(address(usds), wallets.addr("LAUNCH_PROJECT_FUNDING"), 5_000_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BLUE"), 54_167 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BONAPUBLICA"), 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BYTERON"),  4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CLOAKY_2"),  20_417 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("JULIACHANG"),  4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("PBG"), 3_867 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("WBC"), 2_400 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CLOAKY_KOHLA_2"), 11_000 ether), // Note: ether is only a keyword helper
            Payee(address(sky), wallets.addr("BLUE"), 330_000 ether), // Note: ether is only a keyword helper
            Payee(address(sky), wallets.addr("CLOAKY_2"), 288_000 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:          0 ether,         // Note: ether is only a keyword helper
            mkr:          0 ether,         // Note: ether is only a keyword helper
            usds:         5_103_851 ether, // Note: ether is only a keyword helper
            sky:          618_000 ether    // Note: ether is only a keyword helper
        });

        // Fill the total values based on the source for the transfers above
        TreasuryAmounts memory expectedTreasuryBalancesDiff = TreasuryAmounts({
            mkr: 0,
            sky: -618_000 ether
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
        // Note: Uncomment if SKY payments were made using MRR -> SKY conversion
        // assertEq(
        //     (totalSupplyDiff.mkr - treasuryBalancesDiff.mkr) * int256(afterSpell.sky_mkr_rate)
        //         + totalSupplyDiff.sky - treasuryBalancesDiff.sky,
        //     calculatedTotalPayments.mkr * int256(afterSpell.sky_mkr_rate)
        //         + calculatedTotalPayments.sky,
        //     "TestPayments/invalid-mkr-sky-total"
        // );

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

    // Note: this test deliberately ignore changes in SKY and MKR held in the treasury and their supply.
    // TODO: Consider simplifying `testPayments` above to be closer to this one.
    // There is coverage for them in the spell-specific tests.
    function testPayments_ignoreBurnsAndConversions() public {
        Payee[12] memory payees = [
            Payee(address(usds), addr.addr("SPARK_PROXY"),               20_600_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BLUE"),         4_000 ether + 50_167 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("BONAPUBLICA"),                 4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CLOAKY_2"),     4_000 ether + 16_417 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("PBG"),                         4_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("JULIACHANG"),                  2_323 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("EXCEL"),                       1_088 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("WBC"),                         1_032 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("CLOAKY_KOHLA_2"),             11_000 ether), // Note: ether is only a keyword helper,
            Payee(address(sky),  wallets.addr("LAUNCH_PROJECT_FUNDING"),  8_400_000 ether), // Note: ether is only a keyword helper
            Payee(address(sky),  wallets.addr("BLUE"),                      330_000 ether), // Note: ether is only a keyword helper
            Payee(address(sky),  wallets.addr("CLOAKY_2"),                  288_000 ether)  // Note: ether is only a keyword helper
        ];

        // By default the expected balance changes are the payee amounts
        int256[] memory expectedBalanceChanges = new int256[](payees.length);
        for (uint256 i = 0; i < payees.length; i++) {
            expectedBalanceChanges[i] = payees[i].amount;
        }

        // NOTE: the Spark Spell transfer 800,000 USDS out of the Spark Proxy
        expectedBalanceChanges[0] = payees[0].amount - 800_000 ether; // Note: ether is only a keyword helper

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:           0 ether, // Note: ether is only a keyword helper
            mkr:           0 ether, // Note: ether is only a keyword helper
            usds: 20_698_027 ether, // Note: ether is only a keyword helper
            sky:   9_018_000 ether  // Note: ether is only a keyword helper
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

        // Vote, schedule and warp, but not yet cast (to get correct surplus balance)
        _vote(address(spell));
        spell.schedule();
        vm.warp(spell.nextCastTime());
        pot.drip();

        // Calculate and save previous balances
        uint256 previousSurplusBalance = vat.sin(address(vow));

        // Cast spell
        spell.cast();
        assertTrue(spell.done(), "TestPayments/spell-not-done");

        // Check that dai/usds transfers modify surplus buffer
        assertEq(
            vat.sin(address(vow)) - previousSurplusBalance,
            uint256(calculatedTotalPayments.dai + calculatedTotalPayments.usds) * RAY,
            "TestPayments/invalid-vow-sin"
        );

        // Check that payees received their payments
        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i].token == address(dai)) {
                assertEq(
                    int256(dai.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].dai + expectedBalanceChanges[i],
                    "TestPayments/invalid-payee-dai-balance"
                );
            } else if (payees[i].token == address(mkr)) {
                assertEq(
                    int256(mkr.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].mkr + expectedBalanceChanges[i],
                    "TestPayments/invalid-payee-mkr-balance"
                );
            } else if (payees[i].token == address(usds)) {
                assertEq(
                    int256(usds.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].usds + expectedBalanceChanges[i],
                    "TestPayments/invalid-payee-usds-balance"
                );
            } else if (payees[i].token == address(sky)) {
                assertEq(
                    int256(sky.balanceOf(payees[i].addr)),
                    previousPayeeBalances[i].sky + expectedBalanceChanges[i],
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
            addr.addr("CRON_REWARDS_DIST_JOB")
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
            "bafkreidmumjkch6hstk7qslyt3dlfakgb5oi7b3aab7mqj66vkds6ng2de"
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

    // SPARK TESTS
    function testSparkSpellIsExecuted() public { // add the `skipped` modifier to skip
        address SPARK_PROXY = addr.addr('SPARK_PROXY');
        address SPARK_SPELL = address(0x74e1ba852C864d689562b5977EedCB127fDE0C9F); // Insert Spark spell address

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

    // BLOOM TESTS
    function testBloomSpellIsExecuted() public skipped {
        address BLOOM_PROXY = addr.addr('ALLOCATOR_BLOOM_A_SUBPROXY');
        address BLOOM_SPELL = address(0);

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

    // SPELL-SPECIFIC TESTS GO BELOW

    uint256 constant MIN_ETA = 1751292000; // 2025-06-30T14:00:00Z

    function testNextCastTimeMinEta() public {
        // Spell obtains approval for execution before MIN_ETA
        {
            uint256 before = vm.snapshotState();

            vm.warp(1748736000); // 2025-06-01T00:00Z - could be any date far enough in the past
            _vote(address(spell));
            spell.schedule();

            assertEq(spell.nextCastTime(), MIN_ETA, "testNextCastTimeMinEta/min-eta-not-enforced");

            vm.revertToStateAndDelete(before);
        }

        // Spell obtains approval for execution after MIN_ETA
        {
            uint256 before = vm.snapshotState();

            vm.warp(MIN_ETA); // As we move closer to MIN_ETA, GSM delay is still applicable
            _vote(address(spell));
            spell.schedule();

            assertEq(spell.nextCastTime(), MIN_ETA + pause.delay(), "testNextCastTimeMinEta/gsm-delay-not-enforced");

            vm.revertToStateAndDelete(before);
        }
    }

    address SPK = addr.addr("SPK");
    address MCD_VEST_SPK_TREASURY = addr.addr("MCD_VEST_SPK_TREASURY");
    address CRON_SEQUENCER = addr.addr("CRON_SEQUENCER");
    address CRON_REWARDS_DIST_JOB = addr.addr("CRON_REWARDS_DIST_JOB");
    address LOCKSTAKE_ENGINE = addr.addr("LOCKSTAKE_ENGINE");
    address USDS = addr.addr("USDS");
    address LSSKY = addr.addr("LOCKSTAKE_SKY");
    address MCD_PAUSE_PROXY = addr.addr("MCD_PAUSE_PROXY");
    address REWARDS_USDS_SPK = addr.addr("REWARDS_USDS_SPK");
    address REWARDS_DIST_USDS_SPK = addr.addr("REWARDS_DIST_USDS_SPK");
    address REWARDS_LSSKY_SPK = addr.addr("REWARDS_LSSKY_SPK");
    address REWARDS_DIST_LSSKY_SPK = addr.addr("REWARDS_DIST_LSSKY_SPK");

    function test_vestSpkTreasury_deployment() public view {
        // Check the token used for vesting
        assertEq(DssVestLike(MCD_VEST_SPK_TREASURY).gem(), SPK, "MCD_VEST_SPK_TREASURY has wrong gem token");
        // Check the pause proxy is the czar
        assertEq(DssVestLike(MCD_VEST_SPK_TREASURY).czar(), address(pauseProxy), "MCD_VEST_SPK_TREASURY has wrong czar");

        // Check that the pause proxy has authority
        assertEq(WardsLike(MCD_VEST_SPK_TREASURY).wards(address(pauseProxy)), 1, "MCD_PAUSE_PROXY not authorized on MCD_VEST_SPK_TREASURY");

        // Note: Initialization is already tested in `testGeneral`
    }

    function test_usdsSpkFarm_deploymentAndInitialization() public {
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).stakingToken(), USDS, "before: Wrong staking token");
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardsToken(), SPK, "before: Wrong rewards token");

        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).owner(), MCD_PAUSE_PROXY, "before: Wrong owner");
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardsDistribution(), address(0), "before: Wrong rewards distribution");
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardsDuration(), 7 days, "before: Wrong rewards duration");

        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).dssVest(), MCD_VEST_SPK_TREASURY, "before: Wrong DssVest");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).stakingRewards(), REWARDS_USDS_SPK, "before: Wrong StakingRewards");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).gem(), SPK, "before: Wrong gem token");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).wards(MCD_PAUSE_PROXY), 1, "before: PauseProxy not authorized");

        assertEq(
            DssVestLike(MCD_VEST_SPK_TREASURY).gem(),
            address(StakingRewardsLike(REWARDS_USDS_SPK).rewardsToken()),
            "before: DssVest gem != StakingRewards rewardsToken"
        );

        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).vestId(), 0, "before: vestId already set");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).lastDistributedAt(), 0, "before: Should not have distributed yet");
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardRate(), 0, "before: Should have no reward rate");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardsDistribution(), REWARDS_DIST_USDS_SPK, "after: Wrong rewards distribution");
        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardsDuration(), 7 days, "after: Wrong rewards duration");

        uint256 usdsSpkVestId = VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).vestId();
        assertEq(usdsSpkVestId, 1, "after: USDS->SPK vest stream not created");

        (address usdsSpkUsr, , , , , , uint128 usdsSpkTot) =
            DssVestLike(MCD_VEST_SPK_TREASURY).awards(usdsSpkVestId);
        assertEq(usdsSpkUsr, REWARDS_DIST_USDS_SPK, "after: Wrong USDS->SPK vest recipient");
        assertEq(usdsSpkTot, 2_275_000_000 * WAD, "after: Wrong USDS->SPK vest total");

        assertEq(StakingRewardsLike(REWARDS_USDS_SPK).rewardRate(), 2_275_000_000 * WAD / 730 days, "after: USDS->SPK farm invalid reward rate");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_USDS_SPK).lastDistributedAt(), block.timestamp, "after: Should have distributed");
    }

    function test_usdsSpkFarm_stakingDistributionAndUnstaking() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Set the USDS balance of the testing contract
        uint256 stakingAmount = 1_000_000 * WAD;
        address user = address(this);
        deal(address(usds), user, stakingAmount, true);

        // Approve USDS for staking
        usds.approve(REWARDS_USDS_SPK, stakingAmount);

        // Stake USDS
        StakingRewardsLike(REWARDS_USDS_SPK).stake(stakingAmount);

        // Verify staked balance
        uint256 stakedBalance = StakingRewardsLike(REWARDS_USDS_SPK).balanceOf(user);
        assertEq(stakedBalance, stakingAmount, "REWARDS_USDS_SPK/stake-failed");

        // Wait for rewards to accumulate (or fast-forward time in test)
        vm.warp(block.timestamp + 1 days);

        // Check earned rewards
        uint256 earned = StakingRewardsLike(REWARDS_USDS_SPK).earned(user);
        assertGt(earned, 0, "No rewards earned");

        // Claim rewards
        StakingRewardsLike(REWARDS_USDS_SPK).getReward();
        uint256 spkBalance = spk.balanceOf(user);
        assertGt(spkBalance, 0, "Rewards not claimed");

        // Unstake tokens
        StakingRewardsLike(REWARDS_USDS_SPK).withdraw(stakingAmount);

        // Verify USDS returned
        uint256 usdsBalance = usds.balanceOf(user);
        assertGe(usdsBalance, stakingAmount, "Unstaking failed");
    }

    function test_lsskySpkFarm_deploymentAndInitialization() public {
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).stakingToken(), LSSKY, "before: Wrong staking token");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsToken(), SPK, "before: Wrong rewards token");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsDistribution(), address(0), "before: Wrong rewards distribution");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).owner(), MCD_PAUSE_PROXY, "before: Wrong owner");

        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).dssVest(), MCD_VEST_SPK_TREASURY, "before: Wrong DssVest");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).stakingRewards(), REWARDS_LSSKY_SPK, "before: Wrong StakingRewards");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).gem(), SPK, "before: Wrong gem token");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).wards(MCD_PAUSE_PROXY), 1, "before: PauseProxy not authorized");

        assertEq(
            DssVestLike(MCD_VEST_SPK_TREASURY).gem(),
            address(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsToken()),
            "DssVest gem != StakingRewards rewardsToken"
        );

        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).vestId(), 0, "before: vestId already set");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).lastDistributedAt(), 0, "before: Should not have distributed yet");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).totalSupply(), 0, "before: Should have no staked tokens");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardRate(), 0, "before: Should have no reward rate");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsDuration(), 7 days, "before: Wrong rewards duration");

        assertEq(LockstakeEngineLike(LOCKSTAKE_ENGINE).farms(REWARDS_LSSKY_SPK), 0, "before: Farm active in Lockstake Engine");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsDistribution(), REWARDS_DIST_LSSKY_SPK, "after: Wrong rewards distribution");
        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardsDuration(), 7 days, "after: Wrong rewards duration");

        assertEq(LockstakeEngineLike(LOCKSTAKE_ENGINE).farms(REWARDS_LSSKY_SPK), 1, "after: Farm not active in Lockstake Engine");

        uint256 lsskySpkVestId = VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).vestId();
        assertEq(lsskySpkVestId, 2, "after: LSSKY->SPK vest stream not created");

        (address lsskySpkUsr, , , , , , uint128 lsskySpkTot) =
            DssVestLike(MCD_VEST_SPK_TREASURY).awards(lsskySpkVestId);
        assertEq(lsskySpkUsr, REWARDS_DIST_LSSKY_SPK, "after: Wrong LSSKY->SPK vest recipient");
        assertEq(lsskySpkTot, 975_000_000 * WAD, "after: Wrong LSSKY->SPK vest total");

        assertEq(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardRate(), 975_000_000 * WAD / 730 days, "after: LSSKY->SPK farm invalid reward rate");
        assertEq(VestedRewardsDistributionLike(REWARDS_DIST_LSSKY_SPK).lastDistributedAt(), block.timestamp, "after: Should have distributed");
    }

    function test_vestedRewardsDistributionJob_configuration() public {
        assertFalse(VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).has(REWARDS_DIST_USDS_SPK), "before: USDS->SPK farm already registered in cron job");
        assertFalse(VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).has(REWARDS_DIST_LSSKY_SPK), "before: LSSKY->SPK farm already registered in cron job");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertTrue(VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).has(REWARDS_DIST_USDS_SPK), "after: USDS->SPK farm not registered in cron job");
        assertTrue(VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).has(REWARDS_DIST_LSSKY_SPK), "after: LSSKY->SPK farm not registered in cron job");

        uint256 usdsInterval = VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).intervals(REWARDS_DIST_USDS_SPK);
        uint256 lsskyInterval = VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).intervals(REWARDS_DIST_LSSKY_SPK);
        assertEq(usdsInterval, 7 days - 1 hours, "after: Wrong interval for USDS farm");
        assertEq(lsskyInterval, 7 days - 1 hours, "after: Wrong interval for LSSKY farm");
    }

    function test_vestedRewardsDistributionJob_execution() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        uint256 originalTimestamp = block.timestamp;

        // Advance time since distribute() was called in spell
        vm.warp(originalTimestamp + 7 days);

        // Test job execution
        bytes32 network = SequencerLike(CRON_SEQUENCER).getMaster();

        (bool isWorkable, bytes memory args) = (false, "");
        (bool foundUsdsSpk, bool foundLsskySpk) = (false, false);
        do {
            // Note: `workable` is not a view function in this case, so we need to revert to the previous state after calling it.
            uint256 beforeWorkable = vm.snapshotState();
            (isWorkable, args) = VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).workable(network);
            vm.revertToStateAndDelete(beforeWorkable);

            if (isWorkable) {
                address dist = abi.decode(args, (address));
                if (dist == REWARDS_DIST_USDS_SPK) {
                    foundUsdsSpk = true;
                } else if (dist == REWARDS_DIST_LSSKY_SPK) {
                    foundLsskySpk = true;
                }
                // Execute the distribution job
                VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).work(network, args);
            }
        } while(isWorkable);

        // Verify both distributions have been executed
        assertTrue(foundUsdsSpk, "USDS farm not distributed");
        assertTrue(foundLsskySpk, "LSSKY farm not distributed");

        // Verify both farms have reward rates > 0
        assertGt(StakingRewardsLike(REWARDS_USDS_SPK).rewardRate(), 0, "USDS farm reward rate still zero");
        assertGt(StakingRewardsLike(REWARDS_LSSKY_SPK).rewardRate(), 0, "LSSKY farm reward rate still zero");

        // Check if the job is no longer workable
        // Note: `workable` is not a view function in this case, so we need to revert to the previous state after calling it.
        uint256 beforeThirdWorkable = vm.snapshotState();
        (bool thirdWorkable, ) = VestedRewardsDistributionJobLike(CRON_REWARDS_DIST_JOB).workable(network);
        vm.revertToStateAndDelete(beforeThirdWorkable);

        assertFalse(thirdWorkable, "VestedRewardsDistributionJob should not be workable");
    }

    function test_treasuryMkrToSkyConversion_leftoverMkr() public {
        // Get the unpaid MKR for vest ids 9, 18, 24, 35, 37, and 39
        uint256 unpaidMkr = vestMkr.unpaid(9) +
            vestMkr.unpaid(18) +
            vestMkr.unpaid(24) +
            vestMkr.unpaid(35) +
            vestMkr.unpaid(37) +
            vestMkr.unpaid(39);

        // Cast the spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check that the MKR balance has decreased by the expected amount
        uint256 mkrBalanceAfter = mkr.balanceOf(address(pauseProxy));

        // Verify MKR was converted to SKY
        assertEq(mkrBalanceAfter, unpaidMkr, "MKR balance should equal unpaid vest amount");
    }

    function test_disableMkrSkyLegacyConverter() public {
        // Check if MKR_SKY_LEGACY has authority on SKY token before the spell
        assertEq(WardsLike(address(sky)).wards(addr.addr("MKR_SKY_LEGACY")), 1, "MKR_SKY_LEGACY should have authority on SKY before spell");

        // Cast the spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check if MKR_SKY_LEGACY has lost authority on SKY token
        assertEq(WardsLike(address(sky)).wards(addr.addr("MKR_SKY_LEGACY")), 0, "MKR_SKY_LEGACY should not have authority on SKY after spell");
    }

    function test_burnSky() public {
        uint256 skyTotalSupplyBefore = sky.totalSupply();
        uint256 skyTreasuryBalanceBefore = sky.balanceOf(address(pauseProxy));
        uint256 skyConverterBalanceBefore = sky.balanceOf(address(mkrSky));

        uint256 mkrTreasuryBalanceBefore = mkr.balanceOf(address(pauseProxy));
        uint256 mkrTotalSupplyBefore = mkr.totalSupply();
        uint256 conversionRate = mkrSky.rate();

        // Get the unpaid MKR for vest ids 9, 18, 24, 35, 37, and 39
        VestAbstract vestMkr = VestAbstract(addr.addr("MCD_VEST_MKR_TREASURY"));
        uint256 unpaidMkr = vestMkr.unpaid(9) +
            vestMkr.unpaid(18) +
            vestMkr.unpaid(24) +
            vestMkr.unpaid(35) +
            vestMkr.unpaid(37) +
            vestMkr.unpaid(39);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        uint256 expectedSkyTotalSupplyAfter = skyTotalSupplyBefore
            // Excess SKY from the MKR_SKY_LEGACY converter
            - (skyConverterBalanceBefore - mkrTotalSupplyBefore * conversionRate)
            // Amount explicitly burned
            - 426_292_860.23 ether;
        assertEq(
            sky.totalSupply(),
            expectedSkyTotalSupplyAfter,
            "Excess SKY should be burned"
        );

        uint256 expectedSkyTreasuryBalanceAfter = skyTreasuryBalanceBefore
            // Amount from Convert MKR balance of the PauseProxy to SKY
            + (mkrTreasuryBalanceBefore - unpaidMkr) * conversionRate
            // Amount explicitly burned
            - 426_292_860.23 ether
            // Amount transferred to LAUNCH_PROJECT_FUNDING
            - 8_400_000 ether
            // Amount transferred to BLUE
            - 330_000 ether
            // Amount transferred to CLOAKY
            - 288_000 ether;
        assertEq(
            sky.balanceOf(address(pauseProxy)),
            expectedSkyTreasuryBalanceAfter,
            "SKY balance should have increased"
        );
    }
}

