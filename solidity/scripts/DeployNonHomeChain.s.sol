// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {BlockHeaderOracle} from 'contracts/BlockHeaderOracle.sol';
import {NeedsUpdateGuard} from 'contracts/NeedsUpdateGuard.sol';
import {StorageMirrorRootRegistry} from 'contracts/StorageMirrorRootRegistry.sol';
import {VerifierModule} from 'contracts/VerifierModule.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';

import {TestConstants} from 'test/utils/TestConstants.sol';
import {ContractDeploymentAddress} from 'test/utils/ContractDeploymentAddress.sol';

struct DeployVarsNonHomeChain {
  address deployer;
  address storageMirror;
}

abstract contract DeployNonHomeChain is Script, TestConstants {
  function _deployNonHomeChain(DeployVarsNonHomeChain memory _deployVars)
    internal
    returns (
      BlockHeaderOracle _blockHeaderOracle,
      NeedsUpdateGuard _needsUpdateGuard,
      StorageMirrorRootRegistry _storageMirrorRootRegistry,
      VerifierModule _verifierModule
    )
  {
    // Current nonce saved
    uint256 _currentNonce = vm.getNonce(_deployVars.deployer);

    address _storageMirrorRootRegistryTheoriticalAddress =
      ContractDeploymentAddress.addressFrom(_deployVars.deployer, _currentNonce + 2);

    _blockHeaderOracle = new BlockHeaderOracle(); // deployer nonce 0
    console.log('ORACLE: ', address(_blockHeaderOracle));

    _verifierModule =
    new VerifierModule(IStorageMirrorRootRegistry(_storageMirrorRootRegistryTheoriticalAddress), address(_deployVars.storageMirror)); // deployer nonce 1
    console.log('VERIFIER_MODULE: ', address(_verifierModule));

    _storageMirrorRootRegistry =
    new StorageMirrorRootRegistry(address(_deployVars.storageMirror), IVerifierModule(_verifierModule), IBlockHeaderOracle(_blockHeaderOracle)); // deployer nonce 2
    console.log('STORAGE_MIRROR_ROOT_REGISTRY: ', address(_storageMirrorRootRegistry));

    _needsUpdateGuard = new NeedsUpdateGuard(_verifierModule); // deployer nonce 3
    console.log('NEEDS_UPDATE_GUARD: ', address(_needsUpdateGuard));

    string memory _objectKey = 'deployments';
    vm.serializeAddress(_objectKey, 'BlockHeaderOracle', address(_blockHeaderOracle));
    vm.serializeAddress(_objectKey, 'NeedsUpdateGuard', address(_needsUpdateGuard));
    vm.serializeAddress(_objectKey, 'StorageMirrorRootRegistry', address(_storageMirrorRootRegistry));
    string memory _output = vm.serializeAddress(_objectKey, 'VerifierModule', address(_verifierModule));

    vm.writeJson(_output, './solidity/scripts/NonHomeChainDeployments.json');
  }
}
