import 'dotenv/config';
import axios from 'axios';
import { Contract, ethers, utils } from 'ethers';
import { randomUUID } from 'crypto';

const NETWORK_ID = '1';
const CHAINLOG_ADDRESS = '0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F';
const CHIEF_HAT_SLOT = 1;
const DEFAULT_TRANSACTION_PARAMETERS = { gasLimit: 1_000_000_000 };

// check env vars
const REQUIRED_ENV_VARS = ['ETH_RPC_URL', 'TENDERLY_USER', 'TENDERLY_PROJECT', 'TENDERLY_ACCESS_KEY'];
if (REQUIRED_ENV_VARS.some(varName => !process.env[varName])) {
    throw new Error(`Please provide all required env variables: ${REQUIRED_ENV_VARS.join(', ')}`);
}

// check process arguments
const SPELL_ADDRESS = process.argv[2];
if (!SPELL_ADDRESS) {
    throw new Error('Please provide address of the spell, e.g.: `node index.js 0x...`');
}

const getSpellName = async function (spellAddress) {
    const provider = new ethers.providers.JsonRpcProvider(process.env.ETH_RPC_URL);
    const spell = new Contract(
        spellAddress,
        ['function description() external view returns (string memory)'],
        provider
    );
    const description = await spell.description();
    return description.split('|')[0].trim();
};

const makeTenderlyApiRequest = async function ({ method, path, body }) {
    const API_BASE = `https://api.tenderly.co/api/v1/account/${process.env.TENDERLY_USER}/project/${process.env.TENDERLY_PROJECT}`;
    try {
        return await axios[method](`${API_BASE}${path}`, body, {
            headers: {
                'content-type': 'application/json',
                accept: 'application/json, text/plain, */*',
                'X-Access-Key': process.env.TENDERLY_ACCESS_KEY,
            },
        });
    } catch (error) {
        console.error('makeTenderlyApiRequest error', error.response);
        throw new Error(`tenderly request failed with: ${error.code}`);
    }
};

const createTenderlyTestnet = async function (spellName) {
    const slug = `${spellName.replace(/\s+/g, '-').toLowerCase()}-${randomUUID()}`;
    const response = await makeTenderlyApiRequest({
        method: 'post',
        path: '/testnet/container',
        body: {
            slug,
            displayName: spellName,
            description: spellName,
            networkConfig: {
                networkId: NETWORK_ID,
                blockNumber: 'latest',
                baseFeePerGas: '1',
                chainConfig: {
                    chainId: NETWORK_ID,
                },
            },
            explorerConfig:{
                enabled: false,
                verificationVisibility: 'bytecode',
            },
            syncState: true,
        },
    });
    const testnetId = response.data.container?.id;
    if (!testnetId) {
        throw new Error('Failed to create the Tenderly Virtual Testnet');
    }

    const endpoints = response.data.container?.connectivityConfig?.endpoints ?? [];

    const rpcEndpointAdmin = endpoints.find(
        endpoint => endpoint.uri?.startsWith('https://') && endpoint.private === true
    );
    if (!rpcEndpointAdmin) {
        throw new Error('Failed to obtain the admin RPC endpoint');
    }

    return {
        testnetId,
        rpcUrlAdmin: rpcEndpointAdmin.uri,
    };
};

const publishTenderlyTestnet = async function (testnetId) {
    const response = await makeTenderlyApiRequest({
        method: 'put',
        path: `/testnet/container/${testnetId}`,
        body: {
            explorerConfig: {
                enabled: true,
                verificationVisibility: "src"
            },
        },
    });
    // Note: apparently the response schema keeps changing, so the following conditions represent the ones that have been observed.
    if (
        response.data.container?.explorerConfig?.enabled !== true &&
        response.data.container?.explorer_config?.enabled !== true &&
        response.data.container?.explorer_page !== 'ENABLED'
    ) {
        throw new Error('Failed to publish testnet');
    }

    const endpoints = response.data.container?.connectivityConfig?.endpoints ?? [];
    const rpcEndpointPublic = endpoints.find(
        endpoint => endpoint.uri?.startsWith('https://') && endpoint.private === false
    );
    if (!rpcEndpointPublic) {
        throw new Error('Failed to obtain the public RPC endpoint');
    }

    return {
        rpcUrlPublic: rpcEndpointPublic.uri,
        explorerUrlPublic: `https://dashboard.tenderly.co/explorer/vnet/${rpcEndpointPublic.id}`,
    };
};

const giveTheHatToSpell = async function (spellAddress, provider) {
    console.info('Fetching the chief address from chainlog...');
    const chainlog = new Contract(
        CHAINLOG_ADDRESS,
        ['function getAddress(bytes32) external view returns (address)'],
        provider.getSigner()
    );
    const chiefAddress = await chainlog.getAddress(ethers.utils.formatBytes32String('MCD_ADM'));

    console.info('Overwriting the hat...');
    await provider.send('tenderly_setStorageAt', [
        chiefAddress,
        ethers.utils.hexZeroPad(ethers.utils.hexValue(CHIEF_HAT_SLOT), 32),
        ethers.utils.hexZeroPad(spellAddress, 32),
    ]);

    console.info('Checking the hat...');
    const chief = new Contract(chiefAddress, ['function hat() external view returns (address)'], provider.getSigner());
    const hatAddress = await chief.hat();
    if (hatAddress !== spellAddress) {
        throw new Error('Spell does not have the hat');
    }
    console.info('Spell have the hat...\n');
};

const fixChronicleStaleness = async function(provider) {
    async function _fixChronicleStaleness(oracleAddress) {
        const slot = ethers.utils.hexZeroPad(ethers.utils.hexValue(4), 32); // the slot of Chronicle `_pokeData` is 4
        const slotData = await provider.getStorageAt(oracleAddress, slot);

        const packedTypes = ['uint32 age', 'uint128 price'];
        const abiCoder = new ethers.utils.AbiCoder();
        abiCoder._getWordSize = () => 16;

        // Extract price (second half of the uint256 slot)
        const price = abiCoder.decode(packedTypes, slotData).price;

        // Extend age by a 30 days margin
        const age = BigInt(Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60);

        await provider.send('tenderly_setStorageAt', [
            oracleAddress,
            slot,
            abiCoder.encode(packedTypes, [age, price]),
        ]);
    }

    await _fixChronicleStaleness('0x24C392CDbF32Cf911B258981a66d5541d85269ce'); // Chronicle_BTC_USD_3
    await _fixChronicleStaleness('0x46ef0071b1E2fF6B42d36e5A177EA43Ae5917f4E'); // Chronicle_ETH_USD_3
}

const scheduleWarpAndCastSpell = async function (spellAddress, provider) {
    const spell = new Contract(
        spellAddress,
        [
            'function schedule() external',
            'function cast() external',
            'function nextCastTime() external view returns (uint256)',
        ],
        provider.getSigner()
    );

    console.info('Scheduling the spell...');
    const scheduleTx = await spell.schedule(DEFAULT_TRANSACTION_PARAMETERS);
    await scheduleTx.wait();

    console.info('Fetching timestamp when the spell will be castable...');
    const nextCastTime = await spell.nextCastTime();

    console.info(`Warping the time to ${nextCastTime}...`);
    await provider.send('evm_setNextBlockTimestamp', [ethers.utils.hexValue(nextCastTime)]);

    console.info('Casting spell...');
    const castTx = await spell.cast(DEFAULT_TRANSACTION_PARAMETERS);
    await castTx.wait();
    console.info('Successfully cast!\n');
};

const castOnTenderly = async function (spellAddress) {
    const spellName = await getSpellName(spellAddress);
    console.info(`Preparing to cast spell ${spellAddress} with name "${spellName}"...\n`);

    console.info('Creating Tenderly Virtual Testnet...');
    const { testnetId, rpcUrlAdmin } = await createTenderlyTestnet(spellName);
    console.info('Created!\n');

    const provider = new ethers.providers.JsonRpcProvider(rpcUrlAdmin);

    // Temporary fix to the reverts of the Spark spells interacting with Aggor oracles, due to the cast time manipulation
    // Example revert: https://dashboard.tenderly.co/explorer/vnet/eb97d953-4642-4778-938e-d70ee25e3f58/tx/0xe427414d07c28b64c076e809983cfdee3bfd680866ebc7c40349700f4a6160bd?trace=0.5.5.1.62.1.2.0.2.2.0.2.2
    await fixChronicleStaleness(provider);

    await giveTheHatToSpell(spellAddress, provider);

    await scheduleWarpAndCastSpell(spellAddress, provider);

    console.info(`Making Tenderly Virtual Testnet ${testnetId} public...`);
    const { explorerUrlPublic, rpcUrlPublic } = await publishTenderlyTestnet(testnetId);
    console.info(`It is now public and discoverable!\n`);

    console.info(`Tenderly Virtual Testnet for "${spellName}":`);
    console.info('%o', {
        'Testnet ID': testnetId,
        'Admin RPC URL': rpcUrlAdmin,
        'Public RPC URL': rpcUrlPublic,
        'Public Explorer URL': explorerUrlPublic
    });
};

castOnTenderly(utils.getAddress(SPELL_ADDRESS));
