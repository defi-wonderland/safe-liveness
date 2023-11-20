# Safe Liveness

⚠️ The code has not been audited yet, tread with caution.

## Overview

Safe-Liveness is a module that will tackle the liveness problem, one of the main challenges faced by smart wallets to improve cross-chain user experience.

Unlike EOAs, smart wallets have configuration settings, which can cause synchronization problems across chains. Consequently, SAFEs on different chains function as separate contracts, even though they may share the same address and configuration parameters during deployment. This problem becomes critical when there’s a change in the owners’ list.

We will create a module that can verify Safe ownership based on a storage proof, allowing you to easily broadcast any changes in your Safe to other chains.

## Setup

This project uses [Foundry](https://book.getfoundry.sh/). To build it locally, run:

```sh
git clone git@github.com:defi-wonderland/safe-liveness.git
cd safe-liveness
yarn install
yarn build
```

### Available Commands

Make sure to set `MAINNET_RPC` environment variable before running end-to-end tests.

| Yarn Command            | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `yarn build`            | Compile all contracts.                                     |
| `yarn coverage`         | See `forge coverage` report.                               |
| `yarn deploy`           | Deploy the contracts to Mainnet.                  |
| `yarn test`             | Run all unit and e2e tests.                        |
| `yarn test:unit`        | Run unit tests.                                            |
| `yarn test:e2e`         | Run e2e tests.                                     |

## Contributors

Safe-Liveness was built with ❤️ by [Wonderland](https://defi.sucks).

Wonderland is a team of top Web3 researchers, developers, and operators who believe that the future needs to be open-source, permissionless, and decentralized.

[DeFi sucks](https://defi.sucks), but Wonderland is here to make it better.
