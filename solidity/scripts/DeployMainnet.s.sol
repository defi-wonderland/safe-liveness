// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {DeployHomeChain, DeployVars} from 'scripts/DeployHomeChain.s.sol';

// We threat Mainnet as the Home Chain in this case
contract DeployMainnet is DeployHomeChain {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_MAINNNET_PRIVATE_KEY'));

  function run() external {
    vm.startBroadcast(deployer);

    DeployVars memory _deployVars = DeployVars(deployer);

    // Deploy protocol
    _deployHomeChain(_deployVars);

    vm.stopBroadcast();
  }
}
