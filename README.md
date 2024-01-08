# Safe Liveness

⚠️ The code has not been audited yet, tread with caution.

## Overview

Safe-Liveness is a module that will tackle the liveness problem, one of the main challenges faced by smart wallets to improve cross-chain user experience.

Unlike EOAs, smart wallets have configuration settings, which can cause synchronization problems across chains. Consequently, SAFEs on different chains function as separate contracts, even though they may share the same address and configuration parameters during deployment. This problem becomes critical when there’s a change in the owners’ list.

## Setup

This project uses [Foundry](https://book.getfoundry.sh/). To build it locally, run:

```sh
git clone git@github.com:defi-wonderland/safe-liveness.git
cd safe-liveness
yarn install
yarn build
```

## Integration Tests

In order to run the integration tests you will need python setup to generate the proofs, ganache running and some enviroment variables.

1. Set up python and install requirements

```sh
python -m pip install --upgrade pip
pip install -r requirements.txt
```

2. Run ganache

```sh
yarn ganache
```

3. Set enviroment variables

`MAINNET_INTEGRATION_TESTS_RPC` should be the ganache endpoint
`MAINNET_DEPLOYER_PK` should be the deployer of the protocol and a safe owner
`SEARCHER_PK` should be the incentivized actor to verify

4. Run the tests

```sh
yarn test:integration
```

### Available Commands

| Yarn Command            | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `yarn build`            | Compile all contracts.                                     |
| `yarn coverage`         | See `forge coverage` report.                               |
| `yarn deploy`           | Deploy the contracts to Mainnet.                           |
| `yarn test`             | Run all unit and integration tests.                        |
| `yarn test:unit`        | Run unit tests.                                            |
| `yarn test:integration` | Run integration tests.                                     |
| `yarn deploy:mainnet`   | Deploys Home Chain contracts to Mainnet                    |
| `yarn deploy:optimism`  | Deploys Non-Home Chain contracts to Optimism               |
| `yarn deploy:goerli`    | Deploys Home Chain contracts to Goerli                     |
| `yarn deploy:optimismGoerli`| Deploys Non-Home Chain contracts to Optimism Goerli    |
| `yarn docs:build`       | Build the docs                                             |
| `yarn docs:run`         | Runs the docs, needs mdbook                                |
| `yarn ganache`          | Spawn a ganache instance                                   |


## Smart Contracts

### Home Chain
- `UpdateStorageMirrorGuard`: This guard is responsible for calling the GuardCallbackModule when a change in the settings of a safe is executed.
- `GuardCallbackModule`: This contract is a module that is used to save the updated settings to the StorageMirror.
- `StorageMirror`: This contract is a storage of information about the safe’s settings. All safe’s settings changes should be mirrored in this contract and be saved. In the end, this contract’s storage root is gonna be used to see if a proposed update on the non-home chain is valid.

### Non-Home Chain
- `BlockHeaderOracle`: This contract's purpose is to return the latest stored L1 block header and timestamp. Every X minutes a "magical" off-chain agent provides the latest block header and timestamp.
- `NeedsUpdateGuard`: This guard should prevent the safe from executing any transaction if an update is needed. An update is needed based on the owner's security settings that was inputed.
- `VerifierModule`: This contract is the verifier module that verifies the settings of a safe against the StorageMirror on the home chain.
- `StorageMirrorRootRegistry`: This contract should accept and store storageRoots of the StorageMirror contract in L1.


## ⚠️ Warnings

The project is a PoC implementation and should be treated with caution. Bellow we describe some cases that should be taken into account before using the modules/guard.

- `UpdateStorageMirrorGuard` for the PoC this guard is calling the `GuardCallbackModule` in every call. A possible improvement would be to decode the txData, on the guard `checkTransaction` pre-execute hook, and filter against certain function signatures that change the settings of a Safe to accurately catch the change.
- `NeedsUpdateGuard` this guard on the non-home chain can brick the user's safe, since it will block every tx, if their security settings expire. Also it's worth mentioning that before using the guard the safe owner must verify at least 1 set of settings using the VerifierModule in order for the guard to have a point of reference for the latest verified update.
- `VerifierModule` is executing a safeTx after the verification and update of their settings. This safeTx can become invalid since the signatures passed were created before the change of the settings, in this case the user(s) will need to re-sign the tx manually outside of the UI. A possible improvement would be to have a custom safe app that let's you sign even if you are not a "current owner" but are a "potential future owner" of the "soon-to-be-updated" settings
- `VerifierModule` makes the assumption that the address of the safe is the same on both the home chain, and non-home chain. The current implementation will not work if these addresses are different

## Licensing

The primary license for Safe Liveness contracts is MIT, see [`LICENSE`](./LICENSE).

## Contributors

Safe-Liveness was built with ❤️ by [Wonderland](https://defi.sucks).

Wonderland is a team of top Web3 researchers, developers, and operators who believe that the future needs to be open-source, permissionless, and decentralized.

[DeFi sucks](https://defi.sucks), but Wonderland is here to make it better.
