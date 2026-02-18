# spells-mainnet
![Build Status](https://github.com/makerdao/spells-mainnet/actions/workflows/.github/workflows/tests.yaml/badge.svg?branch=master)

Staging repo for MakerDAO executive spells.

## Instructions

### Getting Started

```bash
git clone --recurse-submodules git@github.com:sky-ecosystem/spells-mainnet
```

### Build

```bash
make
```

### Test (Forge without Optimizations)

#### Prerequisites

Install [Foundry](https://github.com/foundry-rs/foundry) latest stable version.

#### Operation
Set `ETH_RPC_URL` to a Mainnet node.

```bash
export ETH_RPC_URL=<Mainnet URL>
make test
```

### Deploy

Provide the following environment variables:
- `ETH_RPC_URL` - a Mainnet RPC URL
- `ETH_KEYSTORE` - a location to the keystore file, e.g. `~/.foundry/keystores/deploy`
- `ETHERSCAN_API_KEY` - an Etherscan API key for spell verification

Then run:

```bash
make deploy
```

#### Estimating gas needed for deployment

Gas estimation is generally handled by Foundry automatically. However, manual limits can be specified as well, refer to the [`forge create` documentation](https://getfoundry.sh/forge/reference/create/).

You can use the following to get a gas estimate for the deploy:

```bash
make estimate
```

Once you have that, add another million gas as a buffer against
out-of-gas errors. Set `ETH_GAS_LIMIT` to this value.

```bash
export ETH_GAS_LIMIT="$((<value from previous step> + 0))"
export ETH_GAS_LIMIT=$(bc <<< "$ETH_GAS_LIMIT + 1000000")
```

You can also check current gas prices on your favorite site
(e.g. https://ethgasstation.info/) and put that gwei value in the
`ETH_GAS_PRICE`.

```bash
export ETH_GAS_PRICE=$(cast --to-wei 420 "gwei")
```

### Cast to tenderly

1. Create Tenderly account (no trial period needed atm) https://dashboard.tenderly.co/register
    - Note down `TENDERLY_USER` and `TENDERLY_PROJECT` values
2. Create Tenderly access token (on the account level!) https://dashboard.tenderly.co/account/authorization
    - Note down `TENDERLY_ACCESS_KEY` values
3. Export required env vars via `export` or create `scripts/cast-on-tenderly/.env` file with them:
    ```env
    ETH_RPC_URL=""
    TENDERLY_USER=""
    TENDERLY_PROJECT=""
    TENDERLY_ACCESS_KEY=""
    ```
4. Execute `make cast-on-tenderly spell=0x...`, with the address of the spell that hasn't been casted yet
    - The execution should finish with `successfully casted`
5. Open the `public explorer url` printed into the console (it should require no credentials)

### Important Note on Secrets

We strongly discourage using `.env` files to store non-revocable secrets (e.g., private keys). Local `.env` files are an easy target for malware and accidental exposure.

Whenever possible, prefer:

* encrypted accounts/keystores supported by our tooling;
* hardware wallets supported by our tooling.

Configure your setup via environment variables that reference those secure sources (rather than embedding raw secrets in a `.env` file).
