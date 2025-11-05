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

contract Config {

    struct SpellValues {
        address   deployed_spell;
        uint256   deployed_spell_created;
        uint256   deployed_spell_block;
        address[] previous_spells;
        bool      office_hours_enabled;
        uint256   expiration_threshold;
    }

    struct SystemValues {
        uint256 line_offset;
        uint256 pause_delay;
        uint256 vow_wait;
        uint256 vow_dump;
        uint256 vow_sump;
        uint256 vow_bump;
        uint256 vow_hump_min;
        uint256 vow_hump_max;
        uint256 split_hop;
        uint256 split_burn;
        bytes32 split_farm;
        uint256 flap_want;
        uint256 dog_Hole;
        uint256 esm_min;
        bytes32 pause_authority;
        bytes32 osm_mom_authority;
        bytes32 clipper_mom_authority;
        bytes32 d3m_mom_authority;
        bytes32 line_mom_authority;
        bytes32 lite_psm_mom_authority;
        bytes32 splitter_mom_authority;
        bytes32 spbeam_mom_authority;
        bytes32 stusds_mom_authority;
        uint256 vest_dai_cap;
        uint256 vest_mkr_cap;
        uint256 vest_usds_cap;
        uint256 vest_sky_cap;
        uint256 vest_sky_mint_cap;
        uint256 vest_spk_cap;
        uint256 SP_tau;
        address SP_bud;
        uint256 SP_ssr_min;
        uint256 SP_ssr_max;
        uint256 SP_ssr_step;
        uint256 SP_dsr_min;
        uint256 SP_dsr_max;
        uint256 SP_dsr_step;
        uint256 sky_mkr_rate;
        uint256 ilk_count;
        string  chainlog_version;
        mapping (bytes32 => CollateralValues) collaterals;
        uint64  stusds_rate_setter_tau;
        uint256 stusds_rate_setter_maxLine;
        uint256 stusds_rate_setter_maxCap;
        uint16  stusds_rate_setter_minStr;
        uint16  stusds_rate_setter_maxStr;
        uint16  stusds_rate_setter_strStep;
        uint16  stusds_rate_setter_minDuty;
        uint16  stusds_rate_setter_maxDuty;
        uint16  stusds_rate_setter_dutyStep;
        address[] stusds_rate_setter_buds;
    }

    enum UpdateMethod {
        // Manual means updates are only done via spells
        MANUAL,
        // AutoLine can update `line`
        AUTOLINE,
        // StUSDS can update `line` and `duty`
        STUSDS
    }

    struct CollateralValues {
        UpdateMethod um;
        uint256 aL_line;
        uint256 aL_gap;
        uint256 aL_ttl;
        uint256 line;
        uint256 dust;
        uint256 pct;
        uint256 mat;
        bytes32 liqType;
        bool    liqOn;
        uint256 chop;
        uint256 dog_hole;
        uint256 clip_buf;
        uint256 clip_tail;
        uint256 clip_cusp;
        uint256 clip_chip;
        uint256 clip_tip;
        uint256 clipper_mom;
        uint256 cm_tolerance;
        uint256 calc_tau;
        uint256 calc_step;
        uint256 calc_cut;
        bool    SP_enabled;
        uint256 SP_min;
        uint256 SP_max;
        uint256 SP_step;
        bool    offboarding;
    }

    uint256 constant private THOUSAND = 10 ** 3;
    uint256 constant private MILLION  = 10 ** 6;
    uint256 constant private BILLION  = 10 ** 9;
    uint256 constant private WAD      = 10 ** 18;
    uint256 constant private RAD      = 10 ** 45;

    SpellValues  spellValues;
    SystemValues afterSpell;

    function setValues() public {
        // Add spells if there is a need to test prior to their cast() functions
        // being called on-chain. They will be executed in order from index 0.
        address[] memory prevSpells = new address[](0);
        // prevSpells[0] = address(0);

        //
        // Values for spell-specific parameters
        //
        spellValues = SpellValues({
            deployed_spell:         address(0), // populate with deployed spell if deployed
            deployed_spell_created: 0,          // use `make deploy-info tx=<deployment-tx>` to obtain the timestamp
            deployed_spell_block:   0,          // use `make deploy-info tx=<deployment-tx>` to obtain the block number
            previous_spells:        prevSpells, // older spells to ensure are executed first
            office_hours_enabled:   true,       // true if officehours is expected to be enabled in the spell
            expiration_threshold:   30 days     // Amount of time before spell expires
        });

        //
        // Values for all system configuration changes
        //
        afterSpell.line_offset            = 700 * MILLION;                                  // Offset between the global line against the sum of local lines
        afterSpell.pause_delay            = 24 hours;                                       // In seconds
        afterSpell.vow_wait               = 156 hours;                                      // In seconds
        afterSpell.vow_dump               = 0;                                              // In whole Dai units
        afterSpell.vow_sump               = type(uint256).max;                              // In whole Dai units
        afterSpell.vow_bump               = 0;                                              // In whole Dai units
        afterSpell.vow_hump_min           = type(uint256).max;                              // In whole Dai units
        afterSpell.vow_hump_max           = type(uint256).max;                              // In whole Dai units
        afterSpell.split_hop              = 2_880 seconds;                                  // In seconds
        afterSpell.split_burn             = 100_00;                                         // In basis points
        afterSpell.split_farm             = "REWARDS_LSSKY_USDS";                           // Farm chainlog key
        afterSpell.flap_want              = 9800;                                           // In basis points
        afterSpell.dog_Hole               = 150 * MILLION;                                  // In whole Dai units
        afterSpell.esm_min                = type(uint256).max;                              // In wei
        afterSpell.pause_authority        = "MCD_ADM";                                      // Pause authority
        afterSpell.osm_mom_authority      = "MCD_ADM";                                      // OsmMom authority
        afterSpell.clipper_mom_authority  = "MCD_ADM";                                      // ClipperMom authority
        afterSpell.d3m_mom_authority      = "MCD_ADM";                                      // D3MMom authority
        afterSpell.line_mom_authority     = "MCD_ADM";                                      // LineMom authority
        afterSpell.lite_psm_mom_authority = "MCD_ADM";                                      // LitePsmMom authority
        afterSpell.splitter_mom_authority = "MCD_ADM";                                      // SplitterMom authority
        afterSpell.spbeam_mom_authority   = "MCD_ADM";                                      // SPBeamMom authority
        afterSpell.stusds_mom_authority   = "MCD_ADM";                                      // Stusds authority
        afterSpell.vest_dai_cap           = 1_000_000 * WAD /  30 days;                     // In WAD Dai per second
        afterSpell.vest_mkr_cap           = 2_220 * WAD / 365 days;                         // In WAD MKR per second
        afterSpell.vest_usds_cap          = 46_200 * WAD /  30 days;                        // In WAD USDS per second
        afterSpell.vest_sky_cap           = 110 * (1_000_000_000 * WAD / 180 days) / 100;   // In WAD SKY per second
        afterSpell.vest_sky_mint_cap      = 176_000_000 * WAD / 182 days;                   // In WAD SKY per second
        afterSpell.vest_spk_cap           = 2_502_500_000 * WAD / 730 days;                 // In WAD SKY per second
        afterSpell.ilk_count              = 31;                                             // Num expected in system
        afterSpell.chainlog_version       = "1.20.8";                                       // String expected in system

        afterSpell.SP_tau       = 57_600 seconds;                             // In seconds
        afterSpell.SP_bud       = 0xe1c6f81D0c3CD570A77813b81AA064c5fff80309; // Address of SPBEAM Bud
        afterSpell.SP_ssr_min   = 2_00;                                       // In basis points
        afterSpell.SP_ssr_max   = 30_00;                                      // In basis points
        afterSpell.SP_ssr_step  = 4_00;                                       // In basis points
        afterSpell.SP_dsr_min   = 0;                                          // In basis points
        afterSpell.SP_dsr_max   = 30_00;                                      // In basis points
        afterSpell.SP_dsr_step  = 4_00;                                       // In basis points
        afterSpell.sky_mkr_rate = 24_000;                                     // In whole SKY/MKR units

        afterSpell.stusds_rate_setter_tau      = 57_600;        // Cooldown period between rate changes in seconds
        afterSpell.stusds_rate_setter_maxLine  = 1_000_000_000; // USDS units
        afterSpell.stusds_rate_setter_maxCap   = 1_000_000_000; // USDS units
        afterSpell.stusds_rate_setter_minStr   = 2_00;          // Minimum allowed rate in bps
        afterSpell.stusds_rate_setter_maxStr   = 50_00;         // Maximum allowed rate in bps
        afterSpell.stusds_rate_setter_strStep  = 5_00;          // Maximum allowed rate change per update (bps)
        afterSpell.stusds_rate_setter_minDuty  = 2_10;          // Minimum allowed rate in bps
        afterSpell.stusds_rate_setter_maxDuty  = 50_00;         // Maximum allowed rate in bps
        afterSpell.stusds_rate_setter_dutyStep = 5_00;          // Maximum allowed rate change per update (bps)

        address[] memory buds = new address[](1);
        buds[0] = 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16;
        afterSpell.stusds_rate_setter_buds = buds; // Array of address

        //
        // Values for all collateral
        // Update when adding or modifying Collateral Values
        //
        afterSpell.collaterals["ETH-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,     // Method for updating collateral values. See UpdateMethod enum for more details
            aL_line:      15 * BILLION,              // In whole Dai units
            aL_gap:       150 * MILLION,             // In whole Dai units
            aL_ttl:       6 hours,                   // In seconds
            line:         0,                         // In whole Dai units. Not checked here as there is auto line
            dust:         7_500,                     // In whole Dai units
            pct:          0,                         // In basis points
            mat:          14500,                     // In basis points
            liqType:      "clip",                    // "" or "flip" or "clip"
            liqOn:        true,                      // If liquidations are enabled
            chop:         1300,                      // In basis points
            dog_hole:     40 * MILLION,              // In whole Dai units
            clip_buf:     110_00,                    // In basis points
            clip_tail:    7_200,                     // In seconds, do not use the 'seconds' keyword
            clip_cusp:    45_00,                     // In basis points
            clip_chip:    10,                        // In basis points
            clip_tip:     250,                       // In whole Dai units
            clipper_mom:  1,                         // 1 if circuit breaker enabled
            cm_tolerance: 5000,                      // In basis points
            calc_tau:     0,                         // In seconds
            calc_step:    90,                        // In seconds
            calc_cut:     9900,                      // In basis points
            SP_enabled:   true,                      // SPBEAM is enabled?
            SP_min:       2_00,                      // In basis points
            SP_max:       30_00,                     // In basis points
            SP_step:      4_00,                      // In basis points
            offboarding:  false                      // If mat is being offboarded
        });
        afterSpell.collaterals["ETH-B"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      250 * MILLION,
            aL_gap:       20 * MILLION,
            aL_ttl:       6 hours,
            line:         0,
            dust:         25 * THOUSAND,
            pct:          0,
            mat:          13000,
            liqType:      "clip",
            liqOn:        true,
            chop:         1300,
            dog_hole:     15 * MILLION,
            clip_buf:     110_00,
            clip_tail:    4_800,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    60,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["ETH-C"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      2 * BILLION,
            aL_gap:       100 * MILLION,
            aL_ttl:       8 hours,
            line:         0,
            dust:         3_500,
            pct:          0,
            mat:          17000,
            liqType:      "clip",
            liqOn:        true,
            chop:         1300,
            dog_hole:     35 * MILLION,
            clip_buf:     110_00,
            clip_tail:    7_200,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    90,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["WBTC-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         7_500,
            pct:          0,
            mat:          15000,
            liqType:      "clip",
            liqOn:        true,
            chop:         0,
            dog_hole:     10 * MILLION,
            clip_buf:     110_00,
            clip_tail:    7_200,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    90,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["WBTC-B"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         25 * THOUSAND,
            pct:          0,
            mat:          15000,
            liqType:      "clip",
            liqOn:        true,
            chop:         0,
            dog_hole:     5 * MILLION,
            clip_buf:     110_00,
            clip_tail:    4_800,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    60,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["WBTC-C"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         3_500,
            pct:          0,
            mat:          17500,
            liqType:      "clip",
            liqOn:        true,
            chop:         0,
            dog_hole:     10 * MILLION,
            clip_buf:     110_00,
            clip_tail:    7_200,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    90,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["PSM-USDC-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "clip",
            liqOn:        false,
            chop:         1300,
            dog_hole:     0,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["LITE-PSM-USDC-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      10 * BILLION,
            aL_gap:       400 * MILLION,
            aL_ttl:       12 hours,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["UNIV2DAIUSDC-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         15 * THOUSAND,
            pct:          2,
            mat:          1000_00,
            liqType:      "clip",
            liqOn:        true,
            chop:         0,
            dog_hole:     400 * THOUSAND,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  true
        });
        afterSpell.collaterals["RWA001-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         15 * MILLION,
            dust:         0,
            pct:          900,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["RWA002-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         50 * MILLION,
            dust:         0,
            pct:          7_00,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["RWA004-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0 * MILLION,
            aL_gap:       0 * MILLION,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          700,
            mat:          11000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["RWA005-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0 * MILLION,
            aL_gap:       0 * MILLION,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          450,
            mat:          10500,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["RWA009-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         100_000_000,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["PSM-PAX-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "clip",
            liqOn:        false,
            chop:         1300,
            dog_hole:     0,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  true
        });
        afterSpell.collaterals["GUNIV3DAIUSDC1-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         15 * THOUSAND,
            pct:          2,
            mat:          10200,
            liqType:      "clip",
            liqOn:        false,
            chop:         1300,
            dog_hole:     5 * MILLION,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["WSTETH-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      750 * MILLION,
            aL_gap:       30 * MILLION,
            aL_ttl:       12 hours,
            line:         0,
            dust:         7_500,
            pct:          0,
            mat:          150_00,
            liqType:      "clip",
            liqOn:        true,
            chop:         1300,
            dog_hole:     30 * MILLION,
            clip_buf:     110_00,
            clip_tail:    7_200,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    90,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["WSTETH-B"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      1 * BILLION,
            aL_gap:       45 * MILLION,
            aL_ttl:       12 hours,
            line:         0,
            dust:         3_500,
            pct:          0,
            mat:          175_00,
            liqType:      "clip",
            liqOn:        true,
            chop:         1300,
            dog_hole:     20 * MILLION,
            clip_buf:     110_00,
            clip_tail:    7_200,
            clip_cusp:    45_00,
            clip_chip:    10,
            clip_tip:     250,
            clipper_mom:  1,
            cm_tolerance: 5000,
            calc_tau:     0,
            calc_step:    90,
            calc_cut:     9900,
            SP_enabled:   true,
            SP_min:       2_00,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["DIRECT-SPK-AAVE-LIDO-USDS"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["DIRECT-AAVEV2-DAI"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["DIRECT-COMPV2-DAI"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["PSM-GUSD-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "clip",
            liqOn:        false,
            chop:         1300,
            dog_hole:     0,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["GUNIV3DAIUSDC2-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         15 * THOUSAND,
            pct:          6,
            mat:          10200,
            liqType:      "clip",
            liqOn:        false,
            chop:         1300,
            dog_hole:     5 * MILLION,
            clip_buf:     10500,
            clip_tail:    220 minutes,
            clip_cusp:    9000,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 9500,
            calc_tau:     0,
            calc_step:    120,
            calc_cut:     9990,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["TELEPORT-FW-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         2_100_000,
            dust:         0,
            pct:          0,
            mat:          0,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["DIRECT-SPARK-DAI"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["DIRECT-SPARK-MORPHO-DAI"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          10000,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["LSE-MKR-A"] = CollateralValues({
            um:           UpdateMethod.MANUAL,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         30_000,
            pct:          20_00,
            mat:          125_00,
            liqType:      "clip",
            liqOn:        true,
            chop:         8_00,
            dog_hole:     3 * MILLION,
            clip_buf:     120_00,
            clip_tail:    100 minutes,
            clip_cusp:    40_00,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  1,
            cm_tolerance: 50_00,
            calc_tau:     0,
            calc_step:    60,
            calc_cut:     99_00,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["LSEV2-SKY-A"] = CollateralValues({
            um:           UpdateMethod.STUSDS,
            aL_line:      0,
            aL_gap:       0,
            aL_ttl:       0,
            line:         0,
            dust:         30_000,
            pct:          0,
            mat:          145_00,
            liqType:      "clip",
            liqOn:        false,
            chop:         13_00,
            dog_hole:     250_000,
            clip_buf:     120_00,
            clip_tail:    100 minutes,
            clip_cusp:    40_00,
            clip_chip:    10,
            clip_tip:     300,
            clipper_mom:  0,
            cm_tolerance: 50_00,
            calc_tau:     0,
            calc_step:    60,
            calc_cut:     99_00,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
        afterSpell.collaterals["ALLOCATOR-SPARK-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      10 * BILLION,
            aL_gap:       500 * MILLION,
            aL_ttl:       24 hours,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   true,
            SP_min:       0,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["ALLOCATOR-NOVA-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      60 * MILLION,
            aL_gap:       1 * MILLION,
            aL_ttl:       20 hours,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   true,
            SP_min:       0,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["ALLOCATOR-BLOOM-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      2_500_000_000,
            aL_gap:       50_000_000,
            aL_ttl:       24 hours,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   true,
            SP_min:       0,
            SP_max:       30_00,
            SP_step:      4_00,
            offboarding:  false
        });
        afterSpell.collaterals["ALLOCATOR-OBEX-A"] = CollateralValues({
            um:           UpdateMethod.AUTOLINE,
            aL_line:      10_000_000,
            aL_gap:       10_000_000,
            aL_ttl:       86_400,
            line:         0,
            dust:         0,
            pct:          0,
            mat:          100_00,
            liqType:      "",
            liqOn:        false,
            chop:         0,
            dog_hole:     0,
            clip_buf:     0,
            clip_tail:    0,
            clip_cusp:    0,
            clip_chip:    0,
            clip_tip:     0,
            clipper_mom:  0,
            cm_tolerance: 0,
            calc_tau:     0,
            calc_step:    0,
            calc_cut:     0,
            SP_enabled:   false,
            SP_min:       0,
            SP_max:       0,
            SP_step:      0,
            offboarding:  false
        });
    }
}
