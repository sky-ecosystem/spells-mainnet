// SPDX-FileCopyrightText: © 2021 Dai Foundation <www.daifoundation.org>
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

contract Wallets {

    mapping (bytes32 => address) public addr;

    constructor() {

        // Core Units
        addr["CES_WALLET"]                   = 0x25307aB59Cd5d8b4E2C01218262Ddf6a89Ff86da;
        addr["CES_OP_WALLET"]                = 0xD740882B8616B50d0B317fDFf17Ec3f4f853F44f;
        addr["COM_WALLET"]                   = 0x1eE3ECa7aEF17D1e74eD7C447CcBA61aC76aDbA9;
        addr["COM_EF_WALLET"]                = 0x99E1696A680c0D9f426Be20400E468089E7FDB0f;
        addr["DAIF_WALLET"]                  = 0x34D8d61050Ef9D2B48Ab00e6dc8A8CA6581c5d63;
        addr["DAIF_RESERVE_WALLET"]          = 0x5F5c328732c9E52DfCb81067b8bA56459b33921f;
        addr["DECO_WALLET"]                  = 0xF482D1031E5b172D42B2DAA1b6e5Cbf6519596f7;
        addr["DIN_WALLET"]                   = 0x7327Aed0Ddf75391098e8753512D8aEc8D740a1F;
        addr["DUX_WALLET"]                   = 0x5A994D8428CCEbCC153863CCdA9D2Be6352f89ad;
        addr["EVENTS_WALLET"]                = 0x3D274fbAc29C92D2F624483495C0113B44dBE7d2;
        addr["GRO_WALLET"]                   = 0x7800C137A645c07132886539217ce192b9F0528e;
        addr["IS_WALLET"]                    = 0xd1F2eEf8576736C1EbA36920B957cd2aF07280F4;
        addr["ORA_WALLET"]                   = 0x2d09B7b95f3F312ba6dDfB77bA6971786c5b50Cf;
        addr["ORA_GAS"]                      = 0x2B6180b413511ce6e3DA967Ec503b2Cc19B78Db6;
        addr["ORA_GAS_EMERGENCY"]            = 0x1A5B692029b157df517b7d21a32c8490b8692b0f;
        addr["PE_WALLET"]                    = 0xe2c16c308b843eD02B09156388Cb240cEd58C01c;
        addr["RISK_WALLET"]                  = 0xb386Bc4e8bAE87c3F67ae94Da36F385C100a370a;
        addr["RISK_WALLET_VEST"]             = 0x5d67d5B1fC7EF4bfF31967bE2D2d7b9323c1521c;
        addr["RWF_WALLET"]                   = 0x96d7b01Cc25B141520C717fa369844d34FF116ec;
        addr["SES_WALLET"]                   = 0x87AcDD9208f73bFc9207e1f6F0fDE906bcA95cc6;
        addr["SF01_WALLET"]                  = 0x4Af6f22d454581bF31B2473Ebe25F5C6F55E028D;
        addr["SH_WALLET"]                    = 0x955993Df48b0458A01cfB5fd7DF5F5DCa6443550;
        addr["SH_MULTISIG"]                  = 0xc657aC882Fb2D6CcF521801da39e910F8519508d;
        addr["SNE_WALLET"]                   = 0x6D348f18c88D45243705D4fdEeB6538c6a9191F1;
        addr["SIDESTREAM_WALLET"]            = 0xb1f950a51516a697E103aaa69E152d839182f6Fe;

        // Recognized Delegates
        addr["ACREINVEST"]                   = 0x5b9C98e8A3D9Db6cd4B4B4C1F92D0A551D06F00D;
        addr["FEEDBLACKLOOPS"]               = 0x80882f2A36d49fC46C3c654F7f9cB9a2Bf0423e1;
        addr["FIELDTECHNOLOGIES"]            = 0x0988E41C02915Fe1beFA78c556f946E5F20ffBD3;
        addr["FLIPFLOPFLAP"]                 = 0x688d508f3a6B0a377e266405A1583B3316f9A2B3;
        addr["GFXLABS"]                      = 0xa6e8772af29b29B9202a073f8E36f447689BEef6;
        addr["JUSTINCASE"]                   = 0xE070c2dCfcf6C6409202A8a210f71D51dbAe9473;
        addr["MAKERMAN"]                     = 0x9AC6A6B24bCd789Fa59A175c0514f33255e1e6D0;
        addr["COLDIRON"]                     = 0x6634e3555DBF4B149c5AEC99D579A2469015AEca;
        addr["MONETSUPPLY"]                  = 0x4Bd73eeE3d0568Bb7C52DFCad7AD5d47Fff5E2CF;
        addr["STABLELAB"]                    = 0x3B91eBDfBC4B78d778f62632a4004804AC5d2DB0;
        addr["FLIPSIDE"]                     = 0x1ef753934C40a72a60EaB12A68B6f8854439AA78;
        addr["PENNBLOCKCHAIN"]               = 0x2165D41aF0d8d5034b9c266597c1A415FA0253bd;
        addr["CHRISBLEC"]                    = 0xa3f0AbB4Ba74512b5a736C5759446e9B50FDA170;
        addr["BLOCKCHAINCOLUMBIA"]           = 0xdC1F98682F4F8a5c6d54F345F448437b83f5E432;
        addr["MHONKASALOTEEMULAU"]           = 0x97Fb39171ACd7C82c439b6158EA2F71D26ba383d;
        addr["LLAMA"]                        = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
        addr["CODEKNIGHT"]                   = 0xf6006d4cF95d6CB2CD1E24AC215D5BF3bca81e7D;
        addr["FRONTIERRESEARCH"]             = 0xA2d55b89654079987CF3985aEff5A7Bd44DA15A8;
        addr["LBSBLOCKCHAIN"]                = 0xB83b3e9C8E3393889Afb272D354A7a3Bd1Fbcf5C;
        addr["ONESTONE"]                     = 0x4eFb12d515801eCfa3Be456B5F348D3CD68f9E8a;
        addr["PVL"]                          = 0x6ebB1A9031177208A4CA50164206BF2Fa5ff7416;
        addr["CALBLOCKCHAIN"]                = 0x7AE109A63ff4DC852e063a673b40BED85D22E585;
        addr["CONSENSYS"]                    = 0xE78658A8acfE982Fde841abb008e57e6545e38b3;
        addr["HKUSTEPI"]                     = 0x2dA0d746938Efa28C7DC093b1da286b3D8bAC34a;

        // AVCs
        addr["IAMMEEOH"]                     = 0x47f7A5d8D27f259582097E1eE59a07a816982AE9;
        addr["ACREDAOS"]                     = 0xBF9226345F601150F64Ea4fEaAE7E40530763cbd;
        addr["SPACEXPONENTIAL"]              = 0xFF8eEB643C5bfDf6A925f2a5F9aDC9198AF07b78;
        addr["RES"]                          = 0x8c5c8d76372954922400e4654AF7694e158AB784;
        addr["LDF"]                          = 0xC322E8Ec33e9b0a34c7cD185C616087D9842ad50;
        addr["OPENSKY"]                      = 0x8e67eE3BbEb1743dc63093Af493f67C3c23C6f04;
        addr["OPENSKY_2"]                    = 0xf44f97f4113759E0a57756bE49C0655d490Cf19F;
        addr["DAVIDPHELPS"]                  = 0xd56e3E325133EFEd6B1687C88571b8a91e517ab0;
        addr["SEEDLATAMETH"]                 = 0x0087a081a9B430fd8f688c6ac5dD24421BfB060D;
        addr["SEEDLATAMETH_2"]               = 0xd43b89621fFd48A8A51704f85fd0C87CbC0EB299;
        addr["STABLELAB_2"]                  = 0xbDE65cf2352ed1Dde959f290E973d0fC5cEDFD08;
        addr["FLIPSIDEGOV"]                  = 0x300901243d6CB2E74c10f8aB4cc89a39cC222a29;
        addr["DAI_VINCI"]                    = 0x9ee47F0f82F1A6F45C4E1D25Ce95C321D8C8356a;
        addr["HARMONY_2"]                    = 0xE20A2e231215e9b7Aa308463F1A7490b2ECE55D3;
        addr["FHOMONEYETH"]                  = 0xdbD5651F71ce83d1f0eD275aC456241890a53C74;
        addr["ROOT"]                         = 0xC74392777443a11Dc26Ce8A3D934370514F38A91;

        // MIP-63 Keeper Network
        addr["GELATO_VEST_STREAMING"]        = 0x478c7Ce3e1df09130f8D65a23AD80e05b352af62;
        addr["GELATO_PAYMENT_ADAPTER"]       = 0x0B5a34D084b6A5ae4361de033d1e6255623b41eD;
        addr["GELATO_TREASURY"]              = 0x5041c60C75633F29DEb2AED79cB0A9ed79202415;
        addr["KEEP3R_VEST_STREAMING"]        = 0x37b375e3D418fbECba6b283e704F840AB32f3b3C;
        addr["KEEP3R_VEST_STREAMING_LEGACY"] = 0xc6A048550C9553F8Ac20fbdeB06f114c27ECcabb;
        addr["KEEP3R_PAYMENT_ADAPTER"]       = 0xaeFed819b6657B3960A8515863abe0529Dfc444A;
        addr["KEEP3R_TREASURY"]              = 0x4DfC6DA2089b0dfCF04788b341197146Ea97f743;
        addr["CHAINLINK_AUTOMATION"]         = 0x5E9dfc5fe95A0754084fB235D58752274314924b;
        addr["CHAINLINK_PAYMENT_ADAPTER"]    = 0xfB5e1D841BDA584Af789bDFABe3c6419140EC065;
        addr["CHAINLINK_TREASURY"]           = 0xBE1cE564574377Acb17C2b7628E4F6dd38067a55;
        addr["TECHOPS_VEST_STREAMING"]       = 0x5A6007d17302238D63aB21407FF600a67765f982;

        // ETH Amsterdam Event SPF
        addr["ETH_AMSTERDAM"]                = 0xF34ac684BA2734039772f0C0d77bc2545e819212;

        // Phoenix Labs SPF
        addr["PHOENIX_LABS"]                 = 0xD9847E6b1314f0327F320E43B51ca0AaAD6FF509;

        // Ambassador Program Pilot Multisig
        addr["AMBASSADOR_WALLET"]            = 0xF411d823a48D18B32e608274Df16a9957fE33E45;

        // Legal Domain Work
        addr["BIBTA_WALLET"]                 = 0x173d85CD1754daD73cfc673944D9C8BF11A01D3F;
        addr["MIP65_WALLET"]                 = 0x29408abeCe474C85a12ce15B05efBB6A1e8587fe;
        addr["BLOCKTOWER_WALLET"]            = 0x117786ad59BC2f13cf25B2359eAa521acB0aDCD9;
        addr["BLOCKTOWER_WALLET_2"]          = 0xc4dB894A11B1eACE4CDb794d0753A3cB7A633767;
        addr["AAVE_V3_TREASURY"]             = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;

        // Responsible Facilitators
        addr["GOV_ALPHA"]                    = 0x01D26f8c5cC009868A4BF66E268c17B057fF7A73;
        addr["TECH"]                         = 0x2dC0420A736D1F40893B9481D8968E4D7424bC0B;
        addr["STEAKHOUSE"]                   = 0xf737C76D2B358619f7ef696cf3F94548fEcec379;
        addr["BA_LABS"]                      = 0xDfe08A40054685E205Ed527014899d1EDe49B892;
        addr["JANSKY"]                       = 0xf3F868534FAD48EF5a228Fe78669cf242745a755;
        addr["VOTEWIZARD"]                   = 0x9E72629dF4fcaA2c2F5813FbbDc55064345431b1;
        addr["ECOSYSTEM_FACILITATOR"]        = 0xFCa6e196c2ad557E64D9397e283C2AFe57344b75;

        // Ecosystem Actors
        addr["PHOENIX_LABS_2"]               = 0x115F76A98C2268DaE6c1421eb6B08e4e1dF525dA;
        addr["VIRIDIAN_STREAM"]              = 0xbB8AA212267477C3dbfF6643E497919ec2E3dEC9;
        addr["VIRIDIAN_TRANSFER"]            = 0xA1E62c6321eEd0ECFcF2f382c8c82FD940D83c07;
        addr["DEWIZ"]                        = 0xD8665628742cf54BBBB3b00B15d7E7a838a1b53a;
        addr["SIDESTREAM"]                   = 0x87EcaaACEd3A02A37e7075dc45D3fEb49867d135;
        addr["PULLUP_LABS"]                  = 0x42aD911c75d25E21727E45eCa2A9d999D5A7f94c;
        addr["CHRONICLE_LABS"]               = 0x68D0ca2d5Ac777F6A9b0d1be44332BB3d5981C2f;
        addr["JETSTREAM"]                    = 0xF478A08C41ad06E8D957d5e6B6Bcde7452cEE962;
        addr["ECOSYSTEM_TEAM"]               = 0x05F471262d15EECA4059DadE070e5BEd509a4e73;

        // Ecosystem Scope
        addr["ECOSYSTEM_SCOPE_WALLET"]       = 0x6E51E0b5813152880C1389E3e860e69E06aD04D9;

        // Accessibility Scope
        addr["LAUNCH_PROJECT_FUNDING"]       = 0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F;

        // Sky Ecosystem Liquidity Bootstrapping
        addr["LIQUIDITY_BOOTSTRAPPING"]      = 0xD8507ef0A59f37d15B5D7b630FA6EEa40CE4AFdD;

        // Integration Boost Initiative
        addr["INTEGRATION_BOOST_INITIATIVE"] = 0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7;

        // Early Bird Rewards Multisig
        addr["EARLY_BIRD_REWARDS"]           = 0x14D98650d46BF7679BBD05D4f615A1547C87Bf68;

        // Sky Frontier Foundation Grant
        addr["SKY_FRONTIER_FOUNDATION"]      = 0xca5183FB9997046fbd9bA8113139bf5a5Af122A0;

        // Fortification Foundation Grant
        addr["FORTIFICATION_FOUNDATION"]     = 0x483413ccCD796Deddee88E4d3e202425d5E891C6;

        // Vest Managers
        addr["PULLUP_LABS_VEST_MGR"]         = 0x9B6213D350A4AFbda2361b6572A07C90c22002F1;

        // Constitutional Delegates
        addr["DEFENSOR"]                     = 0x9542b441d65B6BF4dDdd3d4D2a66D8dCB9EE07a9;
        addr["BONAPUBLICA"]                  = 0x167c1a762B08D7e78dbF8f24e5C3f1Ab415021D3;
        addr["GFXLABS_2"]                    = 0x9B68c14e936104e9a7a24c712BEecdc220002984;
        addr["QGOV"]                         = 0xB0524D8707F76c681901b782372EbeD2d4bA28a6;
        addr["TRUENAME"]                     = 0x612F7924c367575a0Edf21333D96b15F1B345A5d;
        addr["VIGILANT"]                     = 0x2474937cB55500601BCCE9f4cb0A0A72Dc226F61;
        addr["FLIPFLOPFLAP_2"]               = 0x3d9751EFd857662f2B007A881e05CfD1D7833484;
        addr["PBG"]                          = 0x8D4df847dB7FfE0B46AF084fE031F7691C6478c2;
        addr["UPMAKER"]                      = 0xbB819DF169670DC71A16F58F55956FE642cc6BcD;
        addr["WBC"]                          = 0xeBcE83e491947aDB1396Ee7E55d3c81414fB0D47;
        addr["LIBERTAS"]                     = 0xE1eBfFa01883EF2b4A9f59b587fFf1a5B44dbb2f;
        addr["BANDHAR"]                      = 0xE83B6a503A94a5b764CCF00667689B3a522ABc21;
        addr["PALC"]                         = 0x78Deac4F87BD8007b9cb56B8d53889ed5374e83A;
        addr["HARMONY"]                      = 0xF4704Aa4Ad22cAA2A3Dd7A7C529B4C32f7A421F2;
        addr["NAVIGATOR"]                    = 0x11406a9CC2e37425F15f920F494A51133ac93072;
        addr["JAG"]                          = 0x58D1ec57E4294E4fe650D1CB12b96AE34349556f;
        addr["CLOAKY"]                       = 0x869b6d5d8FA7f4FFdaCA4D23FFE0735c5eD1F818;
        addr["CLOAKY_2"]                     = 0x9244F47D70587Fa2329B89B6f503022b63Ad54A5;
        addr["SKYNET"]                       = 0xd4d1A446cD5976a11bd32D3e815A9F85FED2F9F3;
        addr["BLUE"]                         = 0xb6C09680D822F162449cdFB8248a7D3FC26Ec9Bf;
        addr["PIPKIN"]                       = 0x0E661eFE390aE39f90a58b04CF891044e56DEDB7;
        addr["JULIACHANG"]                   = 0x252abAEe2F4f4b8D39E5F12b163eDFb7fac7AED7;
        addr["BYTERON"]                      = 0xc2982e72D060cab2387Dba96b846acb8c96EfF66;
        addr["ROCKY"]                        = 0xC31637BDA32a0811E39456A59022D2C386cb2C85;
        addr["CLOAKY_KOHLA"]                 = 0xA9D43465B43ab95050140668c87A2106C73CA811;
        addr["CLOAKY_ENNOIA"]                = 0xA7364a1738D0bB7D1911318Ca3FB3779A8A58D7b;
        addr["CLOAKY_KOHLA_2"]               = 0x73dFC091Ad77c03F2809204fCF03C0b9dccf8c7a;
        addr["EXCEL"]                        = 0x0F04a22B62A26e25A29Cba5a595623038ef7AcE7;
        addr["AEGIS_D"]                      = 0x78C180CF113Fe4845C325f44648b6567BC79d6E0;
        addr["TANGO"]                        = 0xB2B86A130B1EC101e4Aed9a88502E08995760307;
        addr["SKY_STAKING"]                  = 0x05c73AE49fF0ec654496bF4008d73274a919cB5C;

        // Protocol Engineering Scope
        addr["GOV_SECURITY_ENGINEERING"]     = 0x569fAD613887ddd8c1815b56A00005BCA7FDa9C0;
        addr["MULTICHAIN_ENGINEERING"]       = 0x868B44e8191A2574334deB8E7efA38910df941FA;

        // Whistleblower Bounty
        addr["VENICE_TREE"]                  = 0xCDDd2A697d472d1e8a0B1B188646c756d097b058;
        addr["COMPACTER"]                    = 0xbbd4bC3FE72691663c6ffE984Bcdb6C6E6b3a8Dd;

        // Bug Bounty
        addr["IMMUNEFI_COMISSION"]                    = 0x7119f398b6C06095c6E8964C1f58e7C1BAa79E18;
        addr["IMMUNEFI_USER_PAYOUT_2024_05_16"]       = 0xa24EC79bdF03bB325F36878573B13AedFEd0717f;
        addr["IMMUNEFI_USER_PAYOUT_2024_08_08"]       = 0xA4a6B5f005cBd2eD38f49ac496d86d3528C7a1aa;
        addr["IMMUNEFI_USER_PAYOUT_2025_03_20"]       = 0x29d17B5AcB1C68C574712B11F36C859F6FbdBe32;
        addr["WHITEHAT_PAYOUT_2025_01_09"]            = 0xB5BB14252099CAef65912ad2F1BBd9434cF24c38;

        // Resilience Research Funding
        addr["RESILIENCE_RESEARCH_FUNDING"]  = 0x1378056c0cdd771de52A111E2777293516fA910c;

        // Nova
        addr["NOVA_OPERATOR"]                = 0x0f72935f6de6C54Ce8056FD040d4Ddb012B7cd54;

        // SPBEAM
        addr["SPBEAM_BUD"]                   = 0xe1c6f81D0c3CD570A77813b81AA064c5fff80309;

        // Core Council Multisigs
        addr["CORE_COUNCIL_BUDGET_MULTISIG"]    = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;
        addr["CORE_COUNCIL_DELEGATE_MULTISIG"]  = 0x37FC5d447c8c54326C62b697f674c93eaD2A93A3;

        // Gnosis
        addr["GNOSIS"]                        = 0x849D52316331967b6fF1198e5E32A0eB168D039d;
    }
}
