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

interface SequencerLike {
    function getMaster() external view returns (bytes32);
    function hasJob(address job) external view returns (bool);
}

interface VestedRewardsDistributionLike {
    function vestId() external view returns (uint256);
}

interface ClipperMomLike {
    function tolerance(address) external view returns (uint256);
}

interface StusdsLike is WardsAbstract {
    function chi() external view returns (uint192);
    function rho() external view returns (uint64);
    function str() external view returns (uint256);
    function line() external view returns (uint256);
    function cap() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function ilk() external view returns (bytes32);
    function version() external view returns (string calldata);
    function getImplementation() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function withdraw(uint256, address, address) external returns (uint256);
    function file(bytes32, uint256) external;
}

interface StusdsRateSetterLike {
    function tau() external view returns (uint64);
    function maxLine() external view returns (uint256);
    function maxCap() external view returns (uint256);
    function strCfg() external view returns (uint16, uint16, uint16);
    function dutyCfg() external view returns (uint16, uint16, uint16);
    function buds(address) external view returns (uint256);
    function set(uint256, uint256, uint256, uint256) external;
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
        string[4] memory addedKeys = [
            "STUSDS",
            "STUSDS_IMP",
            "STUSDS_RATE_SETTER",
            "STUSDS_MOM"
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

    function testNewAuthorizations() public { // add the `skipped` modifier to skip
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

    function testVestSky() public { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        // uint256 FEB_01_2025 = 1738368000;

        // Uncomment if contract does not yet have funds to fully pay the award
        deal(address(sky), pauseProxy, 100_000_000 * WAD);

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
                id:  6,
                usr: addr.addr("REWARDS_DIST_USDS_SKY"),
                bgn: block.timestamp,
                clf: block.timestamp,
                fin: block.timestamp + 15_724_800 seconds,
                tau: 15_724_800 seconds,
                mgr: address(0),
                res: 1,
                tot: 76_739_938 * WAD,
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

    function testVestSpk() public skipped { // add the `skipped` modifier to skip
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

    function testYankSky() public { // add the `skipped` modifier to skip
        // Provide human-readable names for timestamps
        uint256 JAN_26_2026_16_11_47 = 1769443907;

        // For each yanked stream, provide Yank object with:
        //   the stream id
        //   the address of the stream
        //   the planned fin of the stream (via variable defined above)
        // Initialize the array with the corrent number of yanks
        Yank[1] memory yanks = [
            Yank(5, chainLog.getAddress("REWARDS_DIST_USDS_SKY"), JAN_26_2026_16_11_47)
        ];

        // Test stream id matches `addr` and `fin`
        VestAbstract vest = VestAbstract(addr.addr("MCD_VEST_SKY_TREASURY"));
        for (uint256 i = 0; i < yanks.length; i++) {
            assertEq(vest.usr(yanks[i].streamId), yanks[i].addr, "testYankSky/unexpected-address");
            assertEq(vest.fin(yanks[i].streamId), yanks[i].finPlanned, "testYankSky/unexpected-fin-date");
        }

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        for (uint256 i = 0; i < yanks.length; i++) {
            // Test stream.fin is set to the current block after the spell
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSky/steam-not-yanked");

            // Give admin powers to test contract address and make the vesting unrestricted for testing
            GodMode.setWard(address(vest), address(this), 1);

            // Test vest can still be called, making stream "invalid" and not changing `fin` timestamp
            vest.unrestrict(yanks[i].streamId);
            vest.vest(yanks[i].streamId);
            assertTrue(!vest.valid(yanks[i].streamId));
            assertEq(vest.fin(yanks[i].streamId), block.timestamp, "testYankSky/steam-fin-changed");
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

    function testPayments() public { // add the `skipped` modifier to skip
        // Note: set to true when there are additional DAI/USDS operations (e.g. surplus buffer sweeps, SubDAO draw-downs) besides direct transfers
        bool ignoreTotalSupplyDaiUsds = false;
        bool ignoreTotalSupplyMkrSky = true;

        // For each payment, create a Payee object with:
        //    the address of the transferred token,
        //    the destination address,
        //    the amount to be paid
        // Initialize the array with the number of payees
        Payee[2] memory payees = [
            Payee(address(usds), wallets.addr("LIQUIDITY_BOOTSTRAPPING"), 8_000_000 ether), // Note: ether is only a keyword helper
            Payee(address(usds), wallets.addr("ECOSYSTEM_TEAM"), 3_000_000 ether) // Note: ether is only a keyword helper
        ];

        // Fill the total values from exec sheet
        PaymentAmounts memory expectedTotalPayments = PaymentAmounts({
            dai:                               0 ether, // Note: ether is only a keyword helper
            mkr:                               0 ether, // Note: ether is only a keyword helper
            usds:                     11_000_000 ether, // Note: ether is only a keyword helper
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

    // SPARK TESTS
    function testSparkSpellIsExecuted() public { // add the `skipped` modifier to skip
        address SPARK_PROXY = addr.addr('SPARK_PROXY');
        address SPARK_SPELL = address(0xe7782847eF825FF37662Ef2F426f2D8c5D904121); // Insert Spark spell address

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

    // Grove/Bloom TESTS
    function testGroveSpellIsExecuted() public skipped { // add the `skipped` modifier to skip
        address GROVE_PROXY = addr.addr('ALLOCATOR_BLOOM_A_SUBPROXY');
        address GROVE_SPELL = address(0xFa533FEd0F065dEf8dcFA6699Aa3d73337302BED); // Insert Grove spell address

        vm.expectCall(
            GROVE_PROXY,
            /* value = */ 0,
            abi.encodeCall(
                ProxyLike(GROVE_PROXY).exec,
                (GROVE_SPELL, abi.encodeWithSignature("execute()"))
            )
        );

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");
    }

    // SPELL-SPECIFIC TESTS GO BELOW

    function testRewardsDistUsdsSkyUpdatedVestIdAndDistribute() public {
        address REWARDS_DIST_USDS_SKY = addr.addr("REWARDS_DIST_USDS_SKY");
        address REWARDS_USDS_SKY = addr.addr("REWARDS_USDS_SKY");

        uint256 vestId = VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).vestId();
        assertEq(vestId, 5, "TestError/rewards-dist-usds-sky-invalid-vest-id-before");

        uint256 unpaidAmount = vestSky.unpaid(5);
        assertTrue(unpaidAmount > 0, "TestError/rewards-dist-usds-sky-unpaid-zero-early");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        vestId = VestedRewardsDistributionLike(REWARDS_DIST_USDS_SKY).vestId();
        assertEq(vestId, 6, "TestError/rewards-dist-usds-sky-invalid-vest-id-after");

        unpaidAmount = vestSky.unpaid(5);
        assertEq(unpaidAmount, 0, "TestError/rewards-dist-usds-sky-unpaid-not-cleared");

        assertEq(StakingRewardsLike(REWARDS_USDS_SKY).lastUpdateTime(), block.timestamp, "TestError/rewards-usds-sky-invalid-last-update-time");
    }

    bytes32 ilk = "LSEV2-SKY-A";
    LockstakeEngineLike engine = LockstakeEngineLike(addr.addr("LOCKSTAKE_ENGINE"));
    OsmAbstract pip = OsmAbstract(addr.addr("PIP_SKY"));
    LockstakeClipperLike clip = LockstakeClipperLike(chainLog.getAddress("LOCKSTAKE_CLIP"));
    LockstakeClipperLike newClip = LockstakeClipperLike(addr.addr("LOCKSTAKE_CLIP"));
    ClipperMomLike clipperMom = ClipperMomLike(addr.addr("CLIPPER_MOM"));
    IlkRegistryAbstract ilkRegistry = IlkRegistryAbstract(addr.addr("ILK_REGISTRY"));
    StusdsLike stusds = StusdsLike(addr.addr("STUSDS"));
    address stUsdsImp = addr.addr("STUSDS_IMP");
    StusdsRateSetterLike rateSetter = StusdsRateSetterLike(addr.addr("STUSDS_RATE_SETTER"));
    ConvLike conv = ConvLike(0xea91A18dAFA1Cb1d2a19DFB205816034e6Fe7e52);
    address bud = 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16;

    function testLockstakeStusdsInit() public {

        assertEq(vat.wards(address(clip)), 1, "TestError/lockstake-stusds-init-vat-wards-clip-pre");
        assertEq(vat.wards(address(newClip)), 0, "TestError/lockstake-stusds-init-vat-wards-newclip-pre");
        assertEq(pip.bud(address(clip)), 1, "TestError/lockstake-stusds-init-pip-bud-clip-pre");
        assertEq(pip.bud(address(newClip)), 0, "TestError/lockstake-stusds-init-pip-bud-newclip-pre");
        (address clipV,,,) = dog.ilks(ilk);
        assertEq(clipV, address(clip), "TestError/lockstake-stusds-init-dog-ilks-clip-pre");
        assertEq(dog.wards(address(clip)), 1, "TestError/lockstake-stusds-init-dog-wards-clip-pre");
        assertEq(dog.wards(address(newClip)), 0, "TestError/lockstake-stusds-init-dog-wards-newclip-pre");
        assertEq(engine.wards(address(clip)), 1, "TestError/lockstake-stusds-init-engine-wards-clip-pre");
        assertEq(engine.wards(address(newClip)), 0, "TestError/lockstake-stusds-init-engine-wards-newclip-pre");
        assertEq(newClip.buf(), RAY, "TestError/lockstake-stusds-init-newclip-buf-pre");
        assertEq(newClip.tail(), 0, "TestError/lockstake-stusds-init-newclip-tail-pre");
        assertEq(newClip.cusp(), 0, "TestError/lockstake-stusds-init-newclip-cusp-pre");
        assertEq(newClip.chip(), 0, "TestError/lockstake-stusds-init-newclip-chip-pre");
        assertEq(newClip.tip(), 0, "TestError/lockstake-stusds-init-newclip-tip-pre");
        assertEq(newClip.stopped(), 0, "TestError/lockstake-stusds-init-newclip-stopped-pre");
        assertEq(newClip.vow(), address(0), "TestError/lockstake-stusds-init-newclip-vow-pre");
        assertEq(newClip.calc(), address(0), "TestError/lockstake-stusds-init-newclip-calc-pre");
        assertEq(newClip.cuttee(), address(0), "TestError/lockstake-stusds-init-newclip-cuttee-pre");
        assertEq(newClip.chost(), 0, "TestError/lockstake-stusds-init-newclip-chost-pre");
        assertEq(clip.wards(address(dog)), 1, "TestError/lockstake-stusds-init-clip-wards-dog-pre");
        assertEq(newClip.wards(address(dog)), 0, "TestError/lockstake-stusds-init-newclip-wards-dog-pre");
        assertEq(clip.wards(address(end)), 1, "TestError/lockstake-stusds-init-clip-wards-end-pre");
        assertEq(newClip.wards(address(end)), 0, "TestError/lockstake-stusds-init-newclip-wards-end-pre");
        assertEq(clip.wards(address(clipperMom)), 0, "TestError/lockstake-stusds-init-clip-wards-clippermom-pre");
        assertEq(newClip.wards(address(clipperMom)), 0, "TestError/lockstake-stusds-init-newclip-wards-clippermom-pre");
        uint256 clipperMomToleranceClipper = clipperMom.tolerance(address(clip));
        assertEq(clipperMom.tolerance(address(newClip)), 0, "TestError/lockstake-stusds-init-clippermom-tolerance-newclip-pre");
        assertEq(ilkRegistry.xlip(ilk), address(clip), "TestError/lockstake-stusds-init-ilkregistry-xlip-pre");
        assertEq(chainLog.getAddress("LOCKSTAKE_CLIP"), address(clip), "TestError/lockstake-stusds-init-chainlog-getaddress-pre");

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        assertEq(vat.wards(address(clip)), 0, "TestError/lockstake-stusds-init-vat-wards-clip-post");
        assertEq(vat.wards(address(newClip)), 1, "TestError/lockstake-stusds-init-vat-wards-newclip-post");
        assertEq(pip.bud(address(clip)), 0, "TestError/lockstake-stusds-init-pip-bud-clip-post");
        assertEq(pip.bud(address(newClip)), 1, "TestError/lockstake-stusds-init-pip-bud-newclip-post");
        (clipV,,,) = dog.ilks(ilk);
        assertEq(clipV, address(newClip), "TestError/lockstake-stusds-init-dog-ilks-clip-post");
        assertEq(dog.wards(address(clip)), 0, "TestError/lockstake-stusds-init-dog-wards-clip-post");
        assertEq(dog.wards(address(newClip)), 1, "TestError/lockstake-stusds-init-dog-wards-newclip-post");
        assertEq(engine.wards(address(clip)), 0, "TestError/lockstake-stusds-init-engine-wards-clip-post");
        assertEq(engine.wards(address(newClip)), 1, "TestError/lockstake-stusds-init-engine-wards-newclip-post");
        assertEq(newClip.buf(), clip.buf(), "TestError/lockstake-stusds-init-newclip-buf-post");
        assertEq(newClip.tail(), clip.tail(), "TestError/lockstake-stusds-init-newclip-tail-post");
        assertEq(newClip.cusp(), clip.cusp(), "TestError/lockstake-stusds-init-newclip-cusp-post");
        assertEq(newClip.chip(), clip.chip(), "TestError/lockstake-stusds-init-newclip-chip-post");
        assertEq(newClip.tip(), clip.tip(), "TestError/lockstake-stusds-init-newclip-tip-post");
        assertEq(newClip.stopped(), 3, "TestError/lockstake-stusds-init-newclip-stopped-post");
        assertEq(newClip.vow(), clip.vow(), "TestError/lockstake-stusds-init-newclip-vow-post");
        assertEq(address(newClip.calc()), address(clip.calc()), "TestError/lockstake-stusds-init-newclip-calc-post");
        assertEq(newClip.cuttee(), address(stusds), "TestError/lockstake-stusds-init-newclip-cuttee-post");
        assertEq(newClip.chost(), clip.chost(), "TestError/lockstake-stusds-init-newclip-chost-post");
        assertEq(clip.wards(address(dog)), 0, "TestError/lockstake-stusds-init-clip-wards-dog-post");
        assertEq(newClip.wards(address(dog)), 1, "TestError/lockstake-stusds-init-newclip-wards-dog-post");
        assertEq(clip.wards(address(end)), 0, "TestError/lockstake-stusds-init-clip-wards-end-post");
        assertEq(newClip.wards(address(end)), 1, "TestError/lockstake-stusds-init-newclip-wards-end-post");
        assertEq(clip.wards(address(clipperMom)), 0, "TestError/lockstake-stusds-init-clip-wards-clippermom-post");
        assertEq(newClip.wards(address(clipperMom)), 0, "TestError/lockstake-stusds-init-newclip-wards-clippermom-post");
        assertEq(stusds.wards(address(newClip)), 1, "TestError/lockstake-stusds-init-stusds-wards-newclip-post");
        assertEq(clipperMom.tolerance(address(newClip)), clipperMomToleranceClipper, "TestError/lockstake-stusds-init-clippermom-tolerance-newclip-post");
        assertEq(ilkRegistry.xlip(ilk), address(newClip), "TestError/lockstake-stusds-init-ilkregistry-xlip-post");
        assertEq(chainLog.getAddress("LOCKSTAKE_CLIP"), address(newClip), "TestError/lockstake-stusds-init-chainlog-getaddress-post");
    }

    function testLockstakeStusdsIntegration() public {
        uint256 dirt1;
        uint256 dirt2;
        uint256 dirt3;

        vm.startPrank(pauseProxy);
        vat.file(ilk, "line", 1_000_000_000e45);
        vm.stopPrank();

        (,,, dirt1) = dog.ilks(ilk);

        address urn = engine.open(0);
        deal(address(sky), address(this), 1_000_000 * WAD);
        sky.approve(address(engine), 1_000_000 * WAD);
        engine.lock(address(this), 0, 1_000_000 * WAD, 5);
        engine.draw(address(this), 0, address(this), 50_000 * WAD);

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // update median price
        vm.store(pip.src(), bytes32(uint256(4)), bytes32(abi.encodePacked(uint32(block.timestamp), uint96(0), uint128(0.04 ether))));
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        vm.prank(pauseProxy);
        pip.kiss(address(this));
        assertEq(uint256(pip.read()), 0.04 ether, "TestError/lockstake-stusds-integration-pip-read");

        // unstop the clipper
        vm.prank(pauseProxy);
        newClip.file("stopped", 0);

        spotter.poke(ilk);
        assertEq(newClip.kicks(), 0, "TestError/lockstake-stusds-integration-newclip-kicks-pre-bark");
        assertEq(engine.urnAuctions(urn), 0, "TestError/lockstake-stusds-integration-engine-urnauctions-pre-bark");
        uint256 salesId = dog.bark(ilk, address(urn), address(this));
        assertEq(newClip.kicks(), 1, "TestError/lockstake-stusds-integration-newclip-kicks-post-bark");
        assertEq(engine.urnAuctions(urn), 1, "TestError/lockstake-stusds-integration-engine-urnauctions-post-bark");

        (,,, dirt2) = dog.ilks(ilk);
        assertGt(dirt2, dirt1, "TestError/lockstake-stusds-integration-dog-ilks-dirt-after-bark");

        uint256 snapshotId = vm.snapshotState();

        (, uint256 tab,, uint256 lot,,,,) = newClip.sales(salesId);
        vm.prank(pauseProxy); vat.suck(address(0), address(this), tab);
        vat.hope(address(newClip));
        newClip.take(salesId, lot, type(uint256).max, address(this), "");

        (,,, dirt3) = dog.ilks(ilk);
        assertEq(dirt3, dirt1, "TestError/lockstake-stusds-integration-dog-ilks-dirt-after-take");

        vm.revertToState(snapshotId);

        vm.warp(block.timestamp + clip.tail() + 1);

        (bool needsRedo,,,) = newClip.getStatus(salesId);
        assertTrue(needsRedo, "TestError/lockstake-stusds-integration-newclip-getstatus-needsredo");

        newClip.redo(salesId, address(this));

        vm.startPrank(pauseProxy);
        newClip.yank(salesId);
        vm.stopPrank();

        (,,, dirt3) = dog.ilks(ilk);
        assertEq(dirt3, dirt1, "TestError/lockstake-stusds-integration-dog-ilks-dirt-after-yank");
    }

    function testStusdsIntegration() public {
        uint256 line1;
        uint256 line2;
        uint256 line3;
        uint256 line4;
        uint256 line5;

        _vote(address(spell));
        _scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        // init
        {
            assertEq(stusds.chi(), RAY, "TestError/stusds-integration-init-chi");
            assertEq(stusds.rho(), block.timestamp, "TestError/stusds-integration-init-rho");
            assertEq(stusds.str(), RAY, "TestError/stusds-integration-init-str");
            assertEq(vat.can(address(stusds), address(usdsJoin)), 1, "TestError/stusds-integration-init-vat-can");
            assertEq(stusds.wards(pauseProxy), 1, "TestError/stusds-integration-init-stusds-wards-pauseproxy");
            assertEq(stusds.version(), "1", "TestError/stusds-integration-init-stusds-version");
            assertEq(stusds.getImplementation(), stUsdsImp, "TestError/stusds-integration-init-stusds-getimplementation");
            assertEq(jug.wards(address(rateSetter)), 1, "TestError/stusds-integration-init-jug-wards-ratesetter");
            assertEq(stusds.wards(address(rateSetter)), 1, "TestError/stusds-integration-init-stusds-wards-ratesetter");
            assertEq(rateSetter.tau(), 57_600, "TestError/stusds-integration-init-ratesetter-tau");
            assertEq(rateSetter.maxLine(),  1_000_000_000 * RAD, "TestError/stusds-integration-init-ratesetter-maxline");
            assertEq(rateSetter.maxCap(), 1_000_000_000 * WAD, "TestError/stusds-integration-init-ratesetter-maxcap");
            (uint16 minStr, uint16 maxStr, uint256 strStep) = rateSetter.strCfg();
            assertEq(minStr, 200, "TestError/stusds-integration-init-ratesetter-strcfg-minstr");
            assertEq(maxStr, 5_000, "TestError/stusds-integration-init-ratesetter-strcfg-maxstr");
            assertEq(strStep, 4_000, "TestError/stusds-integration-init-ratesetter-strcfg-strstep");
            (uint16 minDuty, uint16 maxDuty, uint256 dutyStep) = rateSetter.dutyCfg();
            assertEq(minDuty, 210, "TestError/stusds-integration-init-ratesetter-dutycfg-minduty");
            assertEq(maxDuty, 5_000, "TestError/stusds-integration-init-ratesetter-dutycfg-maxduty");
            assertEq(dutyStep, 4_000, "TestError/stusds-integration-init-ratesetter-dutycfg-dutystep");
            assertEq(rateSetter.buds(bud), 1, "TestError/stusds-integration-init-ratesetter-buds");
        }

        deal(address(usds), address(this), 10e18);
        usds.approve(address(stusds), 10e18);

        uint256 prevSupply = stusds.totalSupply();
        uint256 stusdsUsds = usds.balanceOf(address(stusds));

        uint256 before = vm.snapshotState();
        // deposit
        {
            (,,, line1,) = vat.ilks(stusds.ilk());

            uint256 pie = 1e18 * RAY / stusds.chi();
            stusds.deposit(1e18, address(0xBEEF));

            assertEq(stusds.totalSupply(), prevSupply + pie, "TestError/stusds-integration-deposit-totalsupply");
            assertLe(stusds.totalAssets(), stusdsUsds + 1e18, "TestError/stusds-integration-deposit-totalassets-le");
            assertGe(stusds.totalAssets(), stusdsUsds + 1e18 - 1, "TestError/stusds-integration-deposit-totalassets-ge");
            assertEq(stusds.balanceOf(address(0xBEEF)), pie, "TestError/stusds-integration-deposit-balanceof");
            assertEq(usds.balanceOf(address(stusds)), stusdsUsds + _divup(pie * stusds.chi(), RAY), "TestError/stusds-integration-deposit-usds-balanceof");
            (,,, line2,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line2, line1 + 1e45, 10**14, "TestError/stusds-integration-deposit-line2");

            stusds.deposit(1e18, address(0xBEEF));

            (,,, line3,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line3, line2 + 1e45, 10**14, "TestError/stusds-integration-deposit-line3");

            stdstore
                .target(address(newClip))
                .sig("Due()")
                .checked_write(0.3e45);

            stusds.deposit(1e18, address(0xBEEF));

            (,,, line4,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line4, line3 + 0.7e45, 10**14, "TestError/stusds-integration-deposit-line4"); // Reduced by ongoing auction debt

            vm.prank(pauseProxy);
            stusds.file("line", line4 + 0.2e45);

            stusds.deposit(1e18, address(0xBEEF));

            (,,, line5,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line5, line4 + 0.2e45, 10**14, "TestError/stusds-integration-deposit-line5"); // Limited by line
        }

        vm.revertToStateAndDelete(before);
        // withdraw
        {
            // pushing totalSupply up to allow for withdrawals
            stdstore
                .target(address(stusds))
                .sig("totalSupply()")
                .checked_write(RAY);
            // pushing cap up to allow for deposits with the new total supply
            stdstore
                .target(address(stusds))
                .sig("cap()")
                .checked_write(2 * RAY);

            prevSupply = stusds.totalSupply();

            stusds.deposit(10e18, address(0xBEEF));
            uint256 pie = 10e18 * RAY / stusds.chi();
            (,,, line1,) = vat.ilks(stusds.ilk());
            uint256 shares = _divup(2e45, stusds.chi());

            vm.prank(address(0xBEEF));
            stusds.withdraw(2e18, address(0xAAA), address(0xBEEF));

            assertEq(stusds.totalSupply(), prevSupply + pie - shares, "TestError/stusds-integration-withdraw-totalsupply");
            assertEq(stusds.balanceOf(address(0xBEEF)), pie - shares, "TestError/stusds-integration-withdraw-balanceof");
            assertEq(usds.balanceOf(address(0xAAA)), 2e18, "TestError/stusds-integration-withdraw-usds-balanceof-aaa");
            assertEq(usds.balanceOf(address(stusds)), stusdsUsds + 10e18 - 2e18, "TestError/stusds-integration-withdraw-usds-balanceof-stusds");
            (,,, line2,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line2, line1 - 2e45, 10**14, "TestError/stusds-integration-withdraw-line2");

            vm.prank(address(0xBEEF));
            stusds.withdraw(1e18, address(0xAAA), address(0xBEEF));

            (,,, line3,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line3, line2 - 1e45, 10**14, "TestError/stusds-integration-withdraw-line3");

            stdstore
                .target(address(newClip))
                .sig("Due()")
                .checked_write(0.3e45);

            vm.prank(address(0xBEEF));
            stusds.withdraw(1e18, address(0xAAA), address(0xBEEF));

            (,,, line4,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line4, line3 - 1.3e45, 10**14, "TestError/stusds-integration-withdraw-line4"); // Also reduced by ongoing auction debt

            vm.prank(pauseProxy);
            stusds.file("line", line4 - 2e45);

            vm.prank(address(0xBEEF));
            stusds.withdraw(1e18, address(0xAAA), address(0xBEEF));

            (,,, line5,) = vat.ilks(stusds.ilk());
            assertApproxEqRel(line5, line4 - 2e45, 10**14, "TestError/stusds-integration-withdraw-line5"); // Limited by line

            uint256 rAssets = stusds.balanceOf(address(0xBEEF));
            vm.prank(address(0xBEEF));
            stusds.withdraw(rAssets, address(0xAAA), address(0xBEEF));
            assertEq(stusds.totalSupply(), prevSupply, "TestError/stusds-integration-withdraw-final-totalsupply");
            assertEq(stusds.balanceOf(address(0xBEEF)), 0, "TestError/stusds-integration-withdraw-final-balanceof");
            assertEq(usds.balanceOf(address(0xAAA)), 5e18 + rAssets, "TestError/stusds-integration-withdraw-final-usds-balanceof-aaa");
            assertEq(usds.balanceOf(address(stusds)), stusdsUsds + 10e18 - 5e18 - rAssets, "TestError/stusds-integration-withdraw-final-usds-balanceof-stusds");
        }

        vm.revertToStateAndDelete(before);
        // set rates
        {
            vm.prank(bud);
            rateSetter.set(300, 300, 50_000_000 * RAD, 60_000_000 * WAD);

            (uint256 duty, ) = jug.ilks(ilk);

            assertEq(stusds.str(), conv.btor(300), "TestError/stusds-integration-setrates-str");
            assertEq(duty, conv.btor(300), "TestError/stusds-integration-setrates-duty");
            assertEq(stusds.line(), 50_000_000 * RAD, "TestError/stusds-integration-setrates-line");
            assertEq(stusds.cap(), 60_000_000 * WAD, "TestError/stusds-integration-setrates-cap");
        }
    }
}
