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

contract MockDssSpellAction  {
    function execute() external {}
}
contract MockDssExecSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new MockDssSpellAction())) {}
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

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface SpellActionLike {
    function dao_resolutions() external view returns (string memory);
}

interface SequencerLike {
    function getMaster() external view returns (bytes32);
    function hasJob(address job) external view returns (bool);
}

interface L1GovRelayLike {
    function l2GovernanceRelay() external view returns (address);
    function messenger() external view returns (address);
}

interface L2GovRelayLike {
    function l1GovernanceRelay() external view returns (address);
    function messenger() external view returns (address);
}

interface L2BridgeSpellLike {
    function l2Bridge() external view returns (address);
}

interface DssVestLike {
    function unpaid(uint256 id ) external view returns (uint256);
}

interface VestedRewardsDistributionLike {
    function distribute() external returns (uint256 amount);
    function dssVest() external view returns (address);
    function lastDistributedAt() external view returns (uint256);
    function stakingRewards() external view returns (address);
    function vestId() external view returns (uint256);
}

interface VestedRewardsDistributionJobLike {
    function has(address) external view returns (bool);
    function intervals(address) external view returns (uint256);
}

interface CronJobLike {
    function work(bytes32 network, bytes memory args) external;
    function workable(bytes32 network) external returns (bool, bytes memory);
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
        string[4] memory removedKeys = [
            "LOCKSTAKE_MKR",
            "REWARDS_LSMKR_USDS",
            "MCD_GOV_ACTIONS",
            "GOV_GUARD"
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
        string[13] memory addedKeys = [
            "PIP_SKY",
            "MKR",
            "MKR_GUARD",
            "LOCKSTAKE_MKR_OLD_V1",
            "LOCKSTAKE_ENGINE_OLD_V1",
            "LOCKSTAKE_CLIP_OLD_V1",
            "LOCKSTAKE_CLIP_CALC_OLD_V1",
            "LOCKSTAKE_SKY",
            "LOCKSTAKE_MIGRATOR",
            "MKR_SKY_LEGACY",
            "REWARDS_LSSKY_USDS",
            "REWARDS_LSMKR_USDS_LEGACY",
            "MCD_PROTEGO"
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

    function testLockstakeIlkIntegration() public skipped { // add the `skipped` modifier to skip
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
                farm:   addr.addr("REWARDS_LSSKY_USDS"),
                rToken: addr.addr("USDS"),
                rDistr: addr.addr("MCD_SPLIT"),
                rDur:   1_728 seconds
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

    function testVestDAI() public skipped { // add the `skipped` modifier to skip
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

        _checkVestDai(streams);
    }

    function testVestMKR() public skipped { // add the `skipped` modifier to skip
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

        _checkVestMkr(streams);
    }

    function testVestUSDS() public skipped { // add the `skipped` modifier to skip
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

        _checkVestUsds(streams);
    }

    function testVestSKY() public { // add the `skipped` modifier to skip
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

        _checkVestSKY(streams);
    }

    function testVestSKYmint() public skipped { // add the `skipped` modifier to skip
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

        _checkVestSkyMint(streams);
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

    function testYankSKYmint() public { // add the `skipped` modifier to skip
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
            assertEq(vest.usr(yanks[i].streamId), yanks[i].addr, "testYankSKYmint/unexpected-address");
            assertEq(vest.fin(yanks[i].streamId), yanks[i].finPlanned, "testYankSKYmint/unexpected-fin-date");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
        for (uint256 i = 0; i < yanks.length; i++) {
            // Test stream.fin is set to the current block after the spell
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSKYmint/steam-not-yanked");

            // Give admin powers to test contract address and make the vesting unrestricted for testing
            GodMode.setWard(address(vest), address(this), 1);

            // Test vest can still be called, making stream "invalid" and not changing `fin` timestamp
            vest.unrestrict(yanks[i].streamId);
            vest.vest(yanks[i].streamId);
            assertTrue(!vest.valid(yanks[i].streamId));
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSKYmint/steam-fin-changed");
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

    function testPayments() public { // add the `skipped` modifier to skip
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
        address SPARK_SPELL = address(0x3968a022D955Bbb7927cc011A48601B65a33F346); // Insert Spark spell address

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
    address            immutable SUSDS                      = addr.addr("SUSDS");
    L1TokenBridgeLike  immutable l1UnichainBridge           = L1TokenBridgeLike(addr.addr("UNICHAIN_TOKEN_BRIDGE"));
    L1GovRelayLike     immutable l1UnichainGovRelay         = L1GovRelayLike(addr.addr("UNICHAIN_GOV_RELAY"));
    address            immutable UNICHAIN_ESCROW            = addr.addr("UNICHAIN_ESCROW");
    address            immutable UNICHAIN_TOKEN_BRIDGE_IMP  = addr.addr("UNICHAIN_TOKEN_BRIDGE_IMP");
    address            constant  UNICHAIN_MESSENGER         = 0x9A3D64E386C18Cb1d6d5179a9596A4B5736e98A6;

    L2TokenBridgeLike  immutable l2UnichainBridge           = L2TokenBridgeLike(unichain.addr("L2_UNICHAIN_TOKEN_BRIDGE"));
    address            immutable L2_UNICHAIN_BRIDGE_IMP     = unichain.addr("L2_UNICHAIN_TOKEN_BRIDGE_IMP");
    L2GovRelayLike     immutable l2UnichainGovRelay         = L2GovRelayLike(unichain.addr("L2_UNICHAIN_GOV_RELAY"));
    address            immutable L2_UNICHAIN_SPELL          = unichain.addr("L2_UNICHAIN_SPELL");
    address            immutable L2_UNICHAIN_USDS           = unichain.addr("L2_UNICHAIN_USDS");
    address            immutable L2_UNICHAIN_SUSDS          = unichain.addr("L2_UNICHAIN_SUSDS");
    address            immutable L2_UNICHAIN_MESSENGER      = unichain.addr("L2_UNICHAIN_MESSENGER");

    L1TokenBridgeLike  immutable l1OptimismBridge           = L1TokenBridgeLike(addr.addr("OPTIMISM_TOKEN_BRIDGE"));
    L1GovRelayLike     immutable l1OptimismGovRelay         = L1GovRelayLike(addr.addr("OPTIMISM_GOV_RELAY"));
    address            immutable OPTIMISM_ESCROW            = addr.addr("OPTIMISM_ESCROW");
    address            immutable OPTIMISM_TOKEN_BRIDGE_IMP  = addr.addr("OPTIMISM_TOKEN_BRIDGE_IMP");
    address            constant  OPTIMISM_MESSENGER         = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;

    L2TokenBridgeLike  immutable l2OptimismBridge           = L2TokenBridgeLike(optimism.addr("L2_OPTIMISM_TOKEN_BRIDGE"));
    address            immutable L2_OPTIMISM_BRIDGE_IMP     = optimism.addr("L2_OPTIMISM_TOKEN_BRIDGE_IMP");
    L2GovRelayLike     immutable l2OptimismGovRelay         = L2GovRelayLike(optimism.addr("L2_OPTIMISM_GOV_RELAY"));
    address            immutable L2_OPTIMISM_SPELL          = optimism.addr("L2_OPTIMISM_SPELL");
    address            immutable L2_OPTIMISM_USDS           = optimism.addr("L2_OPTIMISM_USDS");
    address            immutable L2_OPTIMISM_SUSDS          = optimism.addr("L2_OPTIMISM_SUSDS");
    address            immutable L2_OPTIMISM_MESSENGER      = optimism.addr("L2_OPTIMISM_MESSENGER");

    function testLockstakeMigratorDeauthInVat() public {
        address LOCKSTAKE_MIGRATOR = chainLog.getAddress("LOCKSTAKE_MIGRATOR");
        assertEq(vat.wards(LOCKSTAKE_MIGRATOR), 1, "TestError/lockstake-not-ward-in-vat");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(vat.wards(LOCKSTAKE_MIGRATOR), 0, "TestError/lockstake-still-ward-in-vat");
    }

    function testOldRewardsUsdsSkyDistribution() public {
        uint256 vestId = 2;
        DssVestLike vest = DssVestLike(chainLog.getAddress("MCD_VEST_SKY"));
        VestedRewardsDistributionLike distribution = VestedRewardsDistributionLike(chainLog.getAddress("REWARDS_DIST_USDS_SKY"));

        assertGt(vest.unpaid(vestId), 0, "TestError/no-rewards-to-distribute");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(vest.unpaid(vestId), 0, "TestError/rewards-not-distributed");
        assertEq(distribution.lastDistributedAt(), block.timestamp, "TestError/rewards-not-distributed");
    }

    function testVestedRewardsDistributionAllowance() public {
        address vestTreasury = chainLog.getAddress("MCD_VEST_SKY_TREASURY");
        uint256 previousAllowance = sky.allowance(pauseProxy, vestTreasury);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(sky.allowance(pauseProxy, vestTreasury), previousAllowance + (137_500_000 * WAD), "TestError/invalid-allowance");
    }

    function testVestedRewardsDistributionSetup() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(VestedRewardsDistributionLike(chainLog.getAddress("REWARDS_DIST_USDS_SKY")).vestId(), 4);
    }

    function testCronRewardsJobs() public {
        VestedRewardsDistributionJobLike job = VestedRewardsDistributionJobLike(chainLog.getAddress("CRON_REWARDS_DIST_JOB"));
        address prevDistributor = chainLog.getAddress("REWARDS_DIST_USDS_SKY");
        address newDistributor = 0xC8d67Fcf101d3f89D0e1F3a2857485A84072a63F;

        assertTrue(job.has(prevDistributor), "TestError/distributor-does-not-have-job");
        assertFalse(job.has(newDistributor), "TestError/new-distributor-already-has-job");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertFalse(job.has(prevDistributor), "TestError/distributor-job-not-removed");
        assertTrue(job.has(newDistributor), "TestError/new-distributor-job-not-added");
        assertEq(job.intervals(newDistributor), 601200, "TestError/new-distributor-invalid-interval");
    }

    function testUsdsSkyRewardsIntegration() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        StakingRewardsLike rewards = StakingRewardsLike(addr.addr("REWARDS_USDS_SKY"));
        VestedRewardsDistributionLike dist = VestedRewardsDistributionLike(addr.addr("REWARDS_DIST_USDS_SKY"));

        // Sanity checks
        assertEq(rewards.rewardsDistribution(), address(dist), "testUsdsSkyRewards/rewards-rewards-dist-mismatch");
        assertEq(rewards.stakingToken(), address(usds), "testUsdsSkyRewards/rewards-staking-token-mismatch");
        assertEq(rewards.rewardsToken(), address(sky), "testUsdsSkyRewards/rewards-rewards-token-mismatch");

        assertTrue(vestSky.valid(dist.vestId()),               "testUsdsSkyRewards/invalid-dist-vest-id");

        assertEq(dist.dssVest(), address(vestSky), "testUsdsSkyRewards/dist-vest-mismatch");
        assertEq(dist.stakingRewards(), address(rewards), "testUsdsSkyRewards/dist-rewards-mismatch");

        // Check if users can stake and get rewards
        {
            uint256 before = vm.snapshot();

            uint256 stakingWad = 100_000 * WAD;
            _giveTokens(address(usds), stakingWad);
            usds.approve(address(rewards), stakingWad);
            rewards.stake(stakingWad);
            assertEq(rewards.balanceOf(address(this)), stakingWad, "testUsdsSkyRewards/rewards-invalid-staked-balance");

            uint256 pbalance = sky.balanceOf(address(this));
            skip(7 days);
            rewards.getReward();
            assertGt(sky.balanceOf(address(this)), pbalance);

            vm.revertTo(before);
        }

        // Check if distribute can be called again in the future
        {
            uint256 before = vm.snapshot();

            uint256 pbalance = sky.balanceOf(address(rewards));
            skip(7 days);
            dist.distribute();
            assertGt(sky.balanceOf(address(rewards)), pbalance, "testUsdsSkyRewards/distribute-no-increase-balance");

            vm.revertTo(before);
        }
    }

    function testVestedRewardsDistributionJobIntegration() public {
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        SequencerLike seq                         = SequencerLike(addr.addr("CRON_SEQUENCER"));
        CronJobLike job                           = CronJobLike(addr.addr("CRON_REWARDS_DIST_JOB"));
        VestedRewardsDistributionLike distUsdsSky = VestedRewardsDistributionLike(addr.addr("REWARDS_DIST_USDS_SKY"));

        (bool ok, ) = job.workable(seq.getMaster());
        assertFalse(ok, "testVestedRewardsDistributionJob/unexpected-due-job");

        skip(7 days - 1 hours);

        {
            uint256 before = vm.snapshot();

            (bool ok, bytes memory out) = job.workable(seq.getMaster());
            assertTrue(ok, "testVestedRewardsDistributionJob/missing-due-job");
            (address dist) = abi.decode(out, (address));
            assertEq(dist, address(distUsdsSky), "testVestedRewardsDistributionJob/invalid-dist-returned");

            vm.revertTo(before);
        }

        uint256 plastDistributed = distUsdsSky.lastDistributedAt();
        job.work(seq.getMaster(), abi.encode(address(distUsdsSky)));
        assertGt(distUsdsSky.lastDistributedAt(), plastDistributed, "testVestedRewardsDistributionJob/missing-distribution");
    }

    function testUnichainTokenBridgeIntegration() public {
        _setupRootDomain();
        Chain memory chain =
            Chain({name: "Unichain", chainId: 130, chainAlias: "unichain", rpcUrl: "https://unichain.drpc.org"});
        setChain("unichain", chain);
        unichainDomain = new OptimismDomain(config, getChain("unichain"), rootDomain);

        // ------ Sanity checks -------

        unichainDomain.selectFork();

        require(l2UnichainBridge.isOpen()                       == 1, "L2UnichainTokenBridge/not-open");
        require(l2UnichainBridge.otherBridge()                  == address(l1UnichainBridge), "L2UnichainTokenBridge/other-bridge-mismatch");
        require(keccak256(bytes(l2UnichainBridge.version()))    == keccak256("1"), "L2UnichainTokenBridge/version-does-not-match");
        require(l2UnichainBridge.getImplementation()            == L2_UNICHAIN_BRIDGE_IMP, "L2UnichainTokenBridge/imp-does-not-match");
        require(l2UnichainBridge.messenger()                    == L2_UNICHAIN_MESSENGER, "L2UnichainTokenBridge/l2-bridge-messenger-mismatch");
        require(l2UnichainGovRelay.l1GovernanceRelay()          == address(l1UnichainGovRelay), "L2UnichainTokenBridge/l2-gov-relay-mismatch");
        require(l2UnichainGovRelay.messenger()                  == L2_UNICHAIN_MESSENGER, "L2UnichainGovRelay/l2-gov-relay-messenger-mismatch");
        require(L2BridgeSpellLike(L2_UNICHAIN_SPELL).l2Bridge() == address(l2UnichainBridge), "L2UnichainSpell/l2-bridge-mismatch");

        rootDomain.selectFork();

        require(keccak256(bytes(l1UnichainBridge.version()))    == keccak256("1"), "UnichainTokenBridge/version-does-not-match");
        require(l1UnichainBridge.getImplementation()            == UNICHAIN_TOKEN_BRIDGE_IMP, "UnichainTokenBridge/imp-does-not-match");
        require(l1UnichainBridge.isOpen()                       == 1, "UnichainTokenBridge/not-open");
        require(l1UnichainBridge.otherBridge()                  == address(l2UnichainBridge), "UnichainTokenBridge/other-bridge-mismatch");
        require(l1UnichainBridge.messenger()                    == UNICHAIN_MESSENGER, "UnichainTokenBridge/l1-bridge-messenger-mismatch");
        require(l1UnichainGovRelay.l2GovernanceRelay()          == address(l2UnichainGovRelay), "UnichainGovRelay/l2-gov-relay-mismatch");
        require(l1UnichainGovRelay.messenger()                  == UNICHAIN_MESSENGER, "UnichainGovRelay/l1-gov-relay-messenger-mismatch");


        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");


        require(l1UnichainBridge.escrow() == UNICHAIN_ESCROW, "UnichainTokenBridge/escrow-does-not-match");

        address[] memory tokens = new address[](2);
        address[] memory l2tokens = new address[](2);
        uint256[] memory maxWithdrawals = new uint256[](2);

        tokens[0] = address(usds);
        tokens[1] = SUSDS;

        l2tokens[0] = L2_UNICHAIN_USDS;
        l2tokens[1] = L2_UNICHAIN_SUSDS;

        maxWithdrawals[0] = type(uint256).max;
        maxWithdrawals[1] = type(uint256).max;

        _testOpTokenBridgeIntegration(OpTokenBridgeParams({
            l2Bridge:       address(l2UnichainBridge),
            l1Bridge:       address(l1UnichainBridge),
            l1Escrow:       UNICHAIN_ESCROW,
            tokens:         tokens,
            l2Tokens:       l2tokens,
            maxWithdrawals: maxWithdrawals,
            domain:         unichainDomain
        }));
    }

    function testOptimismTokenBridgeIntegration() public {
        _setupRootDomain();
        optimismDomain = new OptimismDomain(config, getChain("optimism"), rootDomain);

        // ------ Sanity checks -------

        optimismDomain.selectFork();

        require(l2OptimismBridge.isOpen()                       == 1, "L2OptimismTokenBridge/not-open");
        require(l2OptimismBridge.otherBridge()                  == address(l1OptimismBridge), "L2OptimismTokenBridge/other-bridge-mismatch");
        require(keccak256(bytes(l2OptimismBridge.version()))    == keccak256("1"), "L2OptimismTokenBridge/version-does-not-match");
        require(l2OptimismBridge.getImplementation()            == L2_OPTIMISM_BRIDGE_IMP, "L2OptimismTokenBridge/imp-does-not-match");
        require(l2OptimismBridge.messenger()                    == L2_OPTIMISM_MESSENGER, "L2OptimismTokenBridge/l2-bridge-messenger-mismatch");
        require(l2OptimismGovRelay.l1GovernanceRelay()          == address(l1OptimismGovRelay), "L2OptimismTokenBridge/l2-gov-relay-mismatch");
        require(l2OptimismGovRelay.messenger()                  == L2_OPTIMISM_MESSENGER, "L2OptimismGovRelay/l2-gov-relay-messenger-mismatch");
        require(L2BridgeSpellLike(L2_OPTIMISM_SPELL).l2Bridge() == address(l2OptimismBridge), "L2OptimismSpell/l2-bridge-mismatch");

        rootDomain.selectFork();

        require(keccak256(bytes(l1OptimismBridge.version()))    == keccak256("1"), "OptimismTokenBridge/version-does-not-match");
        require(l1OptimismBridge.getImplementation()            == OPTIMISM_TOKEN_BRIDGE_IMP, "OptimismTokenBridge/imp-does-not-match");
        require(l1OptimismBridge.isOpen()                       == 1, "OptimismTokenBridge/not-open");
        require(l1OptimismBridge.otherBridge()                  == address(l2OptimismBridge), "OptimismTokenBridge/other-bridge-mismatch");
        require(l1OptimismBridge.messenger()                    == OPTIMISM_MESSENGER, "OptimismTokenBridge/l1-bridge-messenger-mismatch");
        require(l1OptimismGovRelay.l2GovernanceRelay()          == address(l2OptimismGovRelay), "OptimismGovRelay/l2-gov-relay-mismatch");
        require(l1OptimismGovRelay.messenger()                  == OPTIMISM_MESSENGER, "OptimismGovRelay/l1-gov-relay-messenger-mismatch");


        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");


        require(l1OptimismBridge.escrow() == OPTIMISM_ESCROW, "OptimismTokenBridge/escrow-does-not-match");

        address[] memory tokens = new address[](2);
        address[] memory l2tokens = new address[](2);
        uint256[] memory maxWithdrawals = new uint256[](2);

        tokens[0] = address(usds);
        tokens[1] = SUSDS;

        l2tokens[0] = L2_OPTIMISM_USDS;
        l2tokens[1] = L2_OPTIMISM_SUSDS;

        maxWithdrawals[0] = type(uint256).max;
        maxWithdrawals[1] = type(uint256).max;

        _testOpTokenBridgeIntegration(OpTokenBridgeParams({
            l2Bridge:       address(l2OptimismBridge),
            l1Bridge:       address(l1OptimismBridge),
            l1Escrow:       OPTIMISM_ESCROW,
            tokens:         tokens,
            l2Tokens:       l2tokens,
            maxWithdrawals: maxWithdrawals,
            domain:         optimismDomain
        }));
    }

    function testSparkTokenOwnership() public {
        WardsAbstract sparkToken = WardsAbstract(0xc20059e0317DE91738d13af027DfC4a50781b066);
        address sparkCoMultisig = 0x6FE588FDCC6A34207485cc6e47673F59cCEDF92B;

        assertEq(sparkToken.wards(sparkCoMultisig), 0, "TestError/spark-company-multisig-is-ward");
        assertEq(sparkToken.wards(pauseProxy), 1, "TestError/pause-proxy-is-not-ward");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(sparkToken.wards(sparkCoMultisig), 1, "TestError/spark-company-multisig-is-not-ward");
        assertEq(sparkToken.wards(pauseProxy), 0, "TestError/pause-proxy-is-ward");
    }
}
