// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {DeployNonHomeChain, DeployVarsNonHomeChain} from 'scripts/DeployNonHomeChain.s.sol';

// We threat Goerli as the Home Chain in this case
contract DeployOptimismGoerli is DeployNonHomeChain {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_OPTIMISM_PRIVATE_KEY'));
  address public storageMirrorAddress = vm.envAddress('STORAGE_MIRROR_ADDRESS');

  function run() external {
    vm.startBroadcast(deployer);

    DeployVarsNonHomeChain memory _deployVars = DeployVarsNonHomeChain(deployer, storageMirrorAddress);
    // Deploy protocol
    _deployNonHomeChain(_deployVars);

    vm.stopBroadcast();
  }
}
