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

interface LockstakeMigratorLike {
    function flash() external view returns (address);
    function newEngine() external view returns (address);
    function oldEngine() external view returns (address);
    function mkrSky() external view returns (address);
    function migrate(address, uint256, address, uint256, uint16) external;
}

interface AuthedLike {
    function authority() external view returns (address);
}

interface VoteDelegateLike {
    function lock(uint256) external;
    function free(uint256) external;
    function stake(address) external view returns (uint256);
}

interface LineMomLike {
    function ilks(bytes32) external view returns (uint256);
}

interface WardsLike {
    function wards(address) external view returns (uint256);
}

interface OldMkrSkyLike {
    function mkrToSky(address, uint256) external;
    function skyToMkr(address, uint256) external;
}

interface ProtegoLike {
    function drop(address _usr, bytes32 _tag, bytes memory _fax, uint256 _eta) external;
    function pause() external view returns (address);
    function planned(address _usr, bytes32 _tag, bytes memory _fax, uint256 _eta) external view returns (bool);
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

    function testRemovedChainlogKeys() public { // add the `skipped` modifier to skip
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

    function testAddedChainlogKeys() public { // add the `skipped` modifier to skip
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

    function testOsmReaders() public { // add the `skipped` modifier to skip
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

    function testVestSKY() public skipped { // add the `skipped` modifier to skip
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
            tot: 4_752_000 * WAD,
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
            tot: 4_752_000 * WAD,
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
            tot: 4_752_000 * WAD,
            rxd: 0
        });

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
            uint256 before = vm.snapshot();
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

            vm.revertTo(before);
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

    function testYankSKYmint() public skipped { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 SEP_10_2025 = 1757505622;

        // For each yanked stream, provide Yank object with:
        //   the stream id
        //   the address of the stream
        //   the planned fin of the stream (via variable defined above)
        // Initialize the array with the corrent number of yanks
        Yank[1] memory yanks = [
            Yank(1, addr.addr("REWARDS_DIST_USDS_SKY"), SEP_10_2025)
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

    function testPayments() public skipped { // add the `skipped` modifier to skip
        // Note: set to true when there are additional DAI/USDS operations (e.g. surplus buffer sweeps, SubDAO draw-downs) besides direct transfers
        bool ignoreTotalSupplyDaiUsds = false;

        // For each payment, create a Payee object with:
        //    the address of the transferred token,
        //    the destination address,
        //    the amount to be paid
        // Initialize the array with the number of payees
        Payee[3] memory payees = [
            Payee(address(usds), wallets.addr("INTEGRATION_BOOST_INITIATIVE"), 3_000_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("LAUNCH_PROJECT_FUNDING"),       5_000_000 ether), // Note: ether is only a keyword helper
            Payee(address(sky), wallets.addr("LAUNCH_PROJECT_FUNDING"),        30_000_000 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:          0 ether,         // Note: ether is only a keyword helper
            mkr:          0 ether,         // Note: ether is only a keyword helper
            usds:         8_000_000 ether, // Note: ether is only a keyword helper
            sky:          30_000_000 ether // Note: ether is only a keyword helper
        });

        // Fill the total values based on the source for the transfers above
        TreasuryAmounts memory expectedTreasuryBalancesDiff = TreasuryAmounts({
            mkr: -1_250 ether,
            sky: 0
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
        assertEq(
            (totalSupplyDiff.mkr - treasuryBalancesDiff.mkr) * int256(afterSpell.sky_mkr_rate)
                + totalSupplyDiff.sky - treasuryBalancesDiff.sky,
            calculatedTotalPayments.mkr * int256(afterSpell.sky_mkr_rate)
                + calculatedTotalPayments.sky,
            "TestPayments/invalid-mkr-sky-total"
        );

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
        address SPARK_SPELL = address(0xC40611AC4Fff8572Dc5F02A238176edCF15Ea7ba); // Insert Spark spell address

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

    function testNewLineMomIlks() public {
        string[1] memory ilks = [
            "LSEV2-SKY-A"
        ];

        for (uint256 i = 0; i < ilks.length; i++) {
            assertEq(
                LineMomLike(address(lineMom)).ilks(_stringToBytes32(ilks[i])),
                0,
                _concat("testNewLineMomIlks/before-ilk-already-in-lineMom-", ilks[i])
            );
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < ilks.length; i++) {
            assertEq(
                LineMomLike(address(lineMom)).ilks(_stringToBytes32(ilks[i])),
                1,
                _concat("testNewLineMomIlks/after-ilk-not-added-to-lineMom-", ilks[i])
            );
        }
    }

    function testNewOsmMomAddition() public {
        bytes32 ilk = "LSEV2-SKY-A";
        address osm = addr.addr("PIP_SKY");

        // Check values before
        assertEq(osmMom.osms(ilk), address(0), "TestError/osm-already-in-mom");

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check values after
        assertEq(osmMom.osms(ilk), osm, "TestError/osm-not-in-mom");

        // TODO after 2025-05-15: remove additional chief activation
        _activateNewChief();

        // Simulate mom call from emergency spell
        assertEq(OsmAbstract(osm).stopped(), 0, "TestError/unexpected-stopped-before");
        vm.prank(chief.hat()); osmMom.stop(ilk);
        assertEq(OsmAbstract(osm).stopped(), 1, "TestError/unexpected-stopped-after");
    }

    function testOsmSource() public {
        address osm = addr.addr("PIP_SKY");
        address src = addr.addr("FLAP_SKY_ORACLE");

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Sanity checks
        assertEq(OsmAbstract(osm).src(), src, "testOsmSource/incorrect-src");

        // Add test contract to buds for testing
        GodMode.setWard(osm, address(this), 1);
        OsmAbstract(osm).kiss(address(this));

        // Set arbitrary price in the source oracle
        uint256 arbitraryPrice = 12345;
        // Note: this also overwrites `age` to be 0, but it doesn't have any impact on the OSM
        vm.store(src, bytes32(uint256(4)), bytes32(arbitraryPrice));

        // Get values before poke
        (bytes32 currentPrice,) = OsmAbstract(osm).peep();
        uint64 currentZzz = OsmAbstract(osm).zzz();
        OsmAbstract(osm).poke();

        // Get value after poke
        vm.warp(block.timestamp + 1 hours);
        OsmAbstract(osm).poke();
        (bytes32 newPrice,) = OsmAbstract(osm).peep();
        uint64 newZzz = OsmAbstract(osm).zzz();

        // Ensure that changes took place
        assertNotEq(currentPrice, newPrice, "testOsmSource/no-price-change");
        assertNotEq(currentZzz, newZzz, "testOsmSource/no-zzz-change");

        // Ensure price is correctly propagated
        assertEq(uint256(newPrice), arbitraryPrice, "testOsmSource/newPrice-not-arbitraryPrice");
    }

    function testMkrSkyConverterMigration() public {
        uint256 amount = 100 * WAD;

        // Check state before cast
        address oldMkrSky = addr.addr("MKR_SKY_LEGACY");
        assertEq(WardsLike(mkr.authority()).wards(oldMkrSky), 1, "TestError/oldMkrSky-not-yet-authorized-in-mkr-guard");
        assertEq(sky.balanceOf(address(mkrSky)), 0, "TestError/newMkrSky-already-have-minted-sky");

        // Before the migration old converter can swap both ways
        {
            deal(address(mkr), address(this), amount);
            mkr.approve(oldMkrSky, amount);
            OldMkrSkyLike(oldMkrSky).mkrToSky(address(this), amount);
            assertEq(mkr.balanceOf(address(this)), 0, "TestError/before/oldMkrSky.mkrToSky-unexpected-mkr");
            assertEq(sky.balanceOf(address(this)), amount * afterSpell.sky_mkr_rate, "TestError/before/oldMkrSky.mkrToSky-unexpected-sky");
            sky.approve(oldMkrSky, amount * afterSpell.sky_mkr_rate);
            OldMkrSkyLike(oldMkrSky).skyToMkr(address(this), amount * afterSpell.sky_mkr_rate);
            assertEq(sky.balanceOf(address(this)), 0, "TestError/before/oldMkrSky.skyToMkr-unexpected-sky");
            assertEq(mkr.balanceOf(address(this)), amount, "TestError/before/oldMkrSky.skyToMkr-unexpected-mkr");
        }

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check state after cast
        assertEq(WardsLike(mkr.authority()).wards(oldMkrSky), 0, "TestError/oldMkrSky-still-authorized-in-mkr-guard");
        assertEq(sky.balanceOf(address(mkrSky)), mkr.totalSupply() * afterSpell.sky_mkr_rate, "TestError/newMkrSky-have-no-minted-sky");
        assertEq(mkrSky.mkr(), address(mkr), "TestError/newMkrSky-unexpected-mkr-address");
        assertEq(mkrSky.sky(), address(sky), "TestError/newMkrSky-unexpected-sky-address");
        assertEq(mkrSky.rate(), afterSpell.sky_mkr_rate, "TestError/newMkrSky-unexpected-sky-address");

        // After the migration old converter can swap only mkr=>sky
        {
            deal(address(mkr), address(this), amount);
            mkr.approve(oldMkrSky, amount);
            OldMkrSkyLike(oldMkrSky).mkrToSky(address(this), amount);
            assertEq(mkr.balanceOf(address(this)), 0, "TestError/after/oldMkrSky.mkrToSky-unexpected-mkr");
            assertEq(sky.balanceOf(address(this)), amount * afterSpell.sky_mkr_rate, "TestError/after/oldMkrSky.mkrToSky-unexpected-sky");
            sky.approve(oldMkrSky, amount * afterSpell.sky_mkr_rate);
            vm.expectRevert();
            OldMkrSkyLike(oldMkrSky).skyToMkr(address(this), amount * afterSpell.sky_mkr_rate);
        }

        // After the migration new converter can swap mkr=>sky
        {
            deal(address(mkr), address(this), amount);
            deal(address(sky), address(this), 0);
            mkr.approve(address(mkrSky), amount);
            mkrSky.mkrToSky(address(this), amount);
            assertEq(mkr.balanceOf(address(this)), 0, "TestError/after/newMkrSky.mkrToSky-unexpected-mkr");
            assertEq(sky.balanceOf(address(this)), amount * afterSpell.sky_mkr_rate, "TestError/after/newMkrSky.mkrToSky-unexpected-sky");
            assertEq(mkrSky.fee(), 0, "TestError/newMkrSky-unexpected-fee");
            assertEq(mkrSky.take(), 0, "TestError/newMkrSky-unexpected-take");
        }
    }

    ProtegoLike protego = ProtegoLike(addr.addr("MCD_PROTEGO"));

    function _testProtego(bool useNewChief) private {
        MockDssExecSpell badSpell = new MockDssExecSpell();

        // Vote on the badSpell and schedule
        if (useNewChief) {
            _voteWithSky(address(badSpell));
        } else {
            _vote(address(badSpell));
        }
        badSpell.schedule();
        address usr = badSpell.action();
        bytes32 tag = badSpell.tag();
        bytes memory sig = badSpell.sig();
        uint256 eta = badSpell.eta();
        assertTrue(protego.planned(usr, tag, sig, eta), "TestError/not-yet-planned");

        // Vote on the protego and drop
        if (useNewChief) {
            _voteWithSky(address(protego));
        } else {
            _vote(address(protego));
        }
        protego.drop(usr, tag, sig, eta);
        assertFalse(protego.planned(usr, tag, sig, eta), "TestError/still-planned");

        // After Protego loses the hat, it can no longer drop spells
        if (useNewChief) {
            _voteWithSky(address(0));
        } else {
            _vote(address(0));
        }
        vm.expectRevert("ds-auth-unauthorized");
        protego.drop(usr, tag, sig, eta);
    }

    function testProtego() public {
        // Sanity checks
        assertEq(protego.pause(), addr.addr("MCD_PAUSE"));

        // Test before chief migration
        _testProtego(false);

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Test after chief migration
        _activateNewChief();
        _testProtego(true);
    }

    // The following part is ported from the Migration test
    // https://github.com/makerdao/chief-migration/blob/e4a820483694f015a2daf8b1dccc5548036d94d4/test/Migration.t.sol

    function testChiefMigration() public {
        // Check state before cast
        assertNotEq(address(chief), chainLog.getAddress("MCD_ADM"));

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Sanity checks
        assertEq(address(chief), chainLog.getAddress("MCD_ADM"));
        assertEq(chief.hat(), address(0));
        assertEq(chief.live(), 0);
        assertEq(chief.gov(), address(sky));
        assertEq(chief.maxYays(), 5);
        assertEq(chief.launchThreshold(), 2_400_000_000 * WAD);
        assertEq(chief.liftCooldown(), 10);

        // Check changes to authority
        assertEq(pause.authority(), address(chief));
        assertEq(AuthedLike(addr.addr("SPLITTER_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("OSM_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("CLIPPER_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("DIRECT_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("STARKNET_ESCROW_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("LINE_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("LITE_PSM_MOM")).authority(), address(chief));
        assertEq(AuthedLike(addr.addr("SPBEAM_MOM")).authority(), address(chief));

        // Chief can't be launched with lower launchThreshold
        uint256 snapshot = vm.snapshot();
        _giveTokens(address(sky), 1_000 * WAD * 24_000);
        sky.approve(address(chief), 1_000 * WAD * 24_000);
        chief.lock(1_000 * WAD * 24_000);
        chief.vote(new address[](1));
        vm.expectRevert("Chief/less-than-threshold"); chief.launch();
        vm.revertTo(snapshot);

        // Setup: lock enough SKY into new chief
        _giveTokens(address(sky), 100_000 * WAD * 24_000);
        sky.approve(address(chief), 100_000 * WAD * 24_000);
        chief.lock(100_000 * WAD * 24_000);
        address[] memory slate = new address[](1);

        // Check that Mom can't operate since chief is not live
        address splitterStopSpell = addr.addr("EMSP_SPLITTER_STOP");
        slate[0] = splitterStopSpell;
        chief.vote(slate);
        chief.lift(splitterStopSpell);
        vm.expectRevert("SplitterMom/not-authorized"); DssSpell(splitterStopSpell).schedule();

        // Check spell can't schedule since chief is not live
        address testSpell = address(new MockDssExecSpell());
        slate[0] = testSpell;
        chief.vote(slate);
        chief.lift(testSpell);
        vm.expectRevert("ds-auth-unauthorized"); DssSpell(testSpell).schedule();

        // Launch chief
        slate[0] = address(0);
        chief.vote(slate);
        chief.lift(address(0));
        chief.launch();
        assertEq(chief.live(), 1);

        // Mom can't operate since the calling spell is not the hat
        vm.expectRevert("SplitterMom/not-authorized"); DssSpell(splitterStopSpell).schedule();

        // Also test spell can't schedule since not the hat
        vm.expectRevert("ds-auth-unauthorized"); DssSpell(testSpell).schedule();

        // Mom can operate
        slate[0] = splitterStopSpell;
        chief.vote(slate);
        chief.lift(splitterStopSpell);
        assertLe(split.hop(), type(uint256).max);
        DssSpell(splitterStopSpell).schedule();
        assertEq(split.hop(), type(uint256).max);

        // Test spell can schedule
        slate[0] = testSpell;
        chief.vote(slate);
        chief.lift(testSpell);
        DssSpell(testSpell).schedule();

        // Test spell can't cast before gov delay has passed
        vm.expectRevert("ds-pause-premature-exec"); DssSpell(testSpell).cast();

        // Test spell can cast after gov delay has passed
        vm.warp(MockDssExecSpell(testSpell).eta());
        DssSpell(testSpell).cast();
    }

    function testVoteDelegateFactory() public {
        // Check state before cast
        address oldVoteDelegateFactory = chainLog.getAddress("VOTE_DELEGATE_FACTORY");
        assertNotEq(oldVoteDelegateFactory, chainLog.getAddress("VOTE_DELEGATE_FACTORY_LEGACY"));
        assertNotEq(voteDelegateFactory, oldVoteDelegateFactory);

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Sanity checks
        assertEq(oldVoteDelegateFactory, chainLog.getAddress("VOTE_DELEGATE_FACTORY_LEGACY"));
        assertEq(voteDelegateFactory, chainLog.getAddress("VOTE_DELEGATE_FACTORY"));
        assertEq(VoteDelegateFactoryLike(voteDelegateFactory).polling(), VoteDelegateFactoryLike(oldVoteDelegateFactory).polling());
        assertNotEq(VoteDelegateFactoryLike(voteDelegateFactory).chief(), VoteDelegateFactoryLike(oldVoteDelegateFactory).chief());
        assertEq(VoteDelegateFactoryLike(voteDelegateFactory).chief(), address(chief));

        // Setup addresses
        address voter = address(123);
        address delegator = address(456);
        uint256 delegationAmount = 10_000 * WAD;
        deal(address(sky), delegator, delegationAmount);

        // Lock SKY
        uint256 initialSKY = sky.balanceOf(address(chief));
        vm.prank(voter); VoteDelegateLike voteDelegate = VoteDelegateLike(VoteDelegateFactoryLike(voteDelegateFactory).create());
        vm.prank(delegator); sky.approve(address(voteDelegate), type(uint256).max);
        vm.prank(delegator); voteDelegate.lock(delegationAmount);
        assertEq(sky.balanceOf(delegator), 0);
        assertEq(sky.balanceOf(address(chief)), initialSKY + delegationAmount);
        assertEq(voteDelegate.stake(delegator), delegationAmount);

        // Free SKY
        vm.prank(delegator); voteDelegate.free(delegationAmount); // note that we can free in the same block now
        assertEq(sky.balanceOf(delegator), delegationAmount);
        assertEq(sky.balanceOf(address(chief)), initialSKY);
        assertEq(voteDelegate.stake(delegator), 0);
    }

    function testSplitToFarm() public {
        // Check state before cast
        address oldRewards = chainLog.getAddress("REWARDS_LSMKR_USDS");
        assertNotEq(split.farm(), addr.addr("REWARDS_LSSKY_USDS"));
        vm.expectRevert("dss-chain-log/invalid-key"); chainLog.getAddress("REWARDS_LSSKY_USDS");
        vm.expectRevert("dss-chain-log/invalid-key"); chainLog.getAddress("REWARDS_LSMKR_USDS_LEGACY");

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Check chainlog changes
        address splitterFarm = split.farm();
        assertEq(splitterFarm, addr.addr("REWARDS_LSSKY_USDS"));
        assertEq(splitterFarm, chainLog.getAddress("REWARDS_LSSKY_USDS"));
        vm.expectRevert("dss-chain-log/invalid-key"); chainLog.getAddress("REWARDS_LSMKR_USDS");
        assertEq(chainLog.getAddress("REWARDS_LSMKR_USDS_LEGACY"), oldRewards);

        // Sanity checks
        assertEq(StakingRewardsLike(splitterFarm).rewardsDistribution(), address(split));
        assertEq(StakingRewardsLike(splitterFarm).rewardsDuration(), 1_728 seconds);
        assertEq(StakingRewardsLike(splitterFarm).rewardsDuration(), split.hop());
        assertEq(StakingRewardsLike(splitterFarm).owner(), address(pauseProxy));
        assertEq(StakingRewardsLike(splitterFarm).rewardsToken(), address(usds));
        assertEq(StakingRewardsLike(splitterFarm).stakingToken(), addr.addr("LOCKSTAKE_SKY"));

        // Move to a state where calling `vow.flap()` is possible
        vm.warp(block.timestamp + split.hop());
        // Create additional surplus, if needed
        if (vat.dai(address(vow)) < vat.sin(address(vow)) + vow.bump() + vow.hump()) {
            stdstore
                .target(address(vat))
                .sig("dai(address)")
                .with_key(address(vow))
                .checked_write(vat.sin(address(vow)) + vow.bump() + vow.hump());
        }
        // Heal if needed
        if (vat.sin(address(vow)) > vow.Sin() + vow.Ash()) {
            vow.heal(vat.sin(address(vow)) - vow.Sin() - vow.Ash());
        }
        // Set 0% burn
        vm.prank(pauseProxy); split.file("burn", 0);

        // Check flapping result
        uint256 pbalanceUsdsFarm = usds.balanceOf(split.farm());
        vow.flap();
        assertEq(usds.balanceOf(splitterFarm), pbalanceUsdsFarm + vow.bump() / RAY, "testSplitToFarm/invalid-farm-balance");
    }

    // The following part is ported from the LockstakeMigrator test
    // https://github.com/makerdao/lockstake/blob/9cb25125bceb488f39dc4ddd3b54c05217a260d1/test/LockstakeMigrator.t.sol

    LockstakeEngineLike oldEngine  = LockstakeEngineLike(addr.addr("LOCKSTAKE_ENGINE_OLD_V1"));
    LockstakeEngineLike newEngine  = LockstakeEngineLike(addr.addr("LOCKSTAKE_ENGINE"));
    bytes32 oldIlk                 = oldEngine.ilk();
    bytes32 newIlk                 = newEngine.ilk();
    LockstakeMigratorLike migrator = LockstakeMigratorLike(addr.addr("LOCKSTAKE_MIGRATOR"));

    function _ink(bytes32 ilk_, address urn) internal view returns (uint256 ink) {
        (ink,) = vat.urns(ilk_, urn);
    }

    function _art(bytes32 ilk_, address urn) internal view returns (uint256 art) {
        (, art) = vat.urns(ilk_, urn);
    }

    function _Art(bytes32 ilk_) internal view returns (uint256 Art) {
        (Art,,,,) = vat.ilks(ilk_);
    }

    function _rate(bytes32 ilk_) internal view returns (uint256 rate) {
        (, rate,,,) = vat.ilks(ilk_);
    }

    function _line(bytes32 ilk_) internal view returns (uint256 line) {
        (,,, line,) = vat.ilks(ilk_);
    }

    struct Urn {
        address owner;
        uint256 index;
    }

    function _checkLockstakeUrnMigration(Urn memory oldUrn, Urn memory newUrn, address caller, bool hasDebt) internal {
        address oldUrnAddr = oldEngine.ownerUrns(oldUrn.owner, oldUrn.index);
        uint256 oldInkPrev = _ink(oldIlk, oldUrnAddr);
        uint256 oldArtPrev = _art(oldIlk, oldUrnAddr);
        assertGt(oldInkPrev, 0);
        if (hasDebt) {
            assertGt(oldArtPrev, 0);
        } else {
            assertEq(oldArtPrev, 0);
        }

        // Open new urn only if it's not yet done
        address newUrnAddr = newEngine.ownerUrns(newUrn.owner, newUrn.index);
        if (newUrnAddr == address(0)) {
            vm.prank(newUrn.owner); newUrnAddr = newEngine.open(newUrn.index);
        }

        assertEq(_ink(newIlk, newUrnAddr), 0);
        assertEq(_art(newIlk, newUrnAddr), 0);

        // Hope migrator on the old urn only if it's not yet done
        if (oldEngine.urnCan(oldUrnAddr, address(migrator)) == 0) {
            vm.expectRevert("LockstakeEngine/urn-not-authorized");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.prank(oldUrn.owner); oldEngine.hope(oldUrn.owner, oldUrn.index, address(migrator));
        }

        if (hasDebt) {
            // Hope migrator on the new urn only if it's not yet done
            if (newEngine.urnCan(newUrnAddr, address(migrator)) == 0) {
                vm.expectRevert("LockstakeEngine/urn-not-authorized");
                vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
                vm.prank(newUrn.owner); newEngine.hope(newUrn.owner, newUrn.index, address(migrator));
            }

            uint256 snapshotId = vm.snapshot();
            vm.prank(pauseProxy); vat.file(oldIlk, "line", 1);
            vm.expectRevert("LockstakeMigrator/old-ilk-line-not-zero");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.revertTo(snapshotId);
        }

        uint256 oldIlkRate = _rate(oldIlk);

        vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);

        assertEq(_ink(oldIlk, oldUrnAddr), 0);
        assertEq(_art(oldIlk, oldUrnAddr), 0);

        assertEq(_ink(newIlk, newUrnAddr), oldInkPrev * 24_000);
        if (hasDebt) {
            assertApproxEqAbs(_art(newIlk, newUrnAddr) * _rate(newIlk), oldArtPrev * oldIlkRate, RAY * 2);
        } else {
            assertEq(_art(newIlk, newUrnAddr), 0);
        }

        assertEq(_line(newIlk), 0);
    }

    function testLockstakeMigrateCurrentUrnsWithRelevantDebt() public {
        // Check state before cast
        assertEq(oldEngine.wards(address(migrator)), 0, "TestError/migrator-already-authorized-in-old-engine");
        assertEq(vat.wards(address(migrator)), 0, "TestError/migrator-already-authorized-in-vat");

        // Cast spell
        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // Sanity checks
        assertEq(oldEngine.wards(address(migrator)), 1, "TestError/migrator-not-authorized-in-old-engine");
        assertEq(vat.wards(address(migrator)), 1, "TestError/migrator-not-authorized-in-vat");
        assertEq(migrator.oldEngine(), address(oldEngine), "TestError/migrator-invalid-oldEngine");
        assertEq(migrator.newEngine(), address(newEngine), "TestError/migrator-invalid-newEngine");
        assertEq(migrator.mkrSky(), address(mkrSky), "TestError/migrator-invalid-mkrSky");
        assertEq(migrator.flash(), addr.addr("MCD_FLASH"), "TestError/migrator-invalid-mkrSky");

        // Simulate migration of existing urns
        assertEq(_Art(newIlk), 0);
        assertGt(_Art(oldIlk) * _rate(oldIlk), 40_000_000 * RAD);
        _checkLockstakeUrnMigration({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 0 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkLockstakeUrnMigration({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 5 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 1 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkLockstakeUrnMigration({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 7 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 2 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkLockstakeUrnMigration({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 6 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 3 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkLockstakeUrnMigration({
            oldUrn: Urn({ owner: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7, index: 0 }),
            newUrn: Urn({ owner: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7, index: 0 }),
            caller: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7,
            hasDebt: true
        });
        assertGt(_Art(newIlk) * _rate(newIlk), 40_000_000 * RAD);
        assertLt(_Art(oldIlk) * _rate(oldIlk),  1_000_000 * RAD);
    }
}
