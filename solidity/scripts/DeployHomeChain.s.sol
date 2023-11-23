// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {StorageMirror} from 'contracts/StorageMirror.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {GuardCallbackModule} from 'contracts/GuardCallbackModule.sol';

import {TestConstants} from 'test/utils/TestConstants.sol';
import {ContractDeploymentAddress} from 'test/utils/ContractDeploymentAddress.sol';

struct DeployVars {
  address deployer;
}

abstract contract Deploy is Script, TestConstants {
  function _deploy(DeployVars memory _deployVars)
    internal
    returns (
      StorageMirror _storageMirror,
      UpdateStorageMirrorGuard _updateStorageMirrorGuard,
      GuardCallbackModule _guardCallbackModule
    )
  {
    // Current nonce saved
    uint256 _currentNonce = vm.getNonce(_deployVars.deployer);

    // Guard theoritical address since we need it for the deployment of the module
    address _updateStorageMirrorGuardTheoriticalAddress =
      ContractDeploymentAddress.addressFrom(_deployVars.deployer, _currentNonce + 2);

    // Deploy storage mirror
    _storageMirror = new StorageMirror(); // deployer nonce 0
    console.log('STORAGE_MIRROR: ', address(_storageMirror));

    _guardCallbackModule = new GuardCallbackModule(address(_storageMirror), _updateStorageMirrorGuardTheoriticalAddress); // deployer nonce 1
    console.log('GUARD_CALLBACK_MODULE: ', address(_guardCallbackModule));

    _updateStorageMirrorGuard = new UpdateStorageMirrorGuard(_guardCallbackModule); // deployer nonce 2
    console.log('UPDATE_STORAGE_MIRROR_GUARD: ', address(_updateStorageMirrorGuard));

    console.log('DEPLOYMENT DONE');
  }
}
