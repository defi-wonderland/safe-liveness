// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {Script} from 'forge-std/Script.sol';

import {StorageMirror} from 'contracts/StorageMirror.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {GuardCallbackModule} from 'contracts/GuardCallbackModule.sol';
import {BlockHeaderOracle} from 'contracts/BlockHeaderOracle.sol';
import {NeedsUpdateGuard} from 'contracts/NeedsUpdateGuard.sol';
import {VerifierModule} from 'contracts/VerifierModule.sol';
import {StorageMirrorRootRegistry} from 'contracts/StorageMirrorRootRegistry.sol';

import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';

import {IGnosisSafeProxyFactory} from 'test/e2e/IGnosisSafeProxyFactory.sol';
import {TestConstants} from 'test/utils/TestConstants.sol';
import {ContractDeploymentAddress} from 'test/utils/ContractDeploymentAddress.sol';

// solhint-disable-next-line max-states-count
contract CommonE2EBase is DSTestPlus, TestConstants, Script {
  uint256 internal constant _MAINNET_FORK_BLOCK = 18_621_047;
  uint256 internal constant _OPTIMISM_FORK_BLOCK = 112_491_451;

  uint256 internal _mainnetForkId;
  uint256 internal _optimismForkId;

  address internal _deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));
  address internal _searcher = vm.rememberKey(vm.envUint('SEARCHER_PK'));

  address[] internal _owners = [_deployer];

  StorageMirror public storageMirror;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;
  GuardCallbackModule public guardCallbackModule;
  BlockHeaderOracle public oracle;
  NeedsUpdateGuard public needsUpdateGuard;
  VerifierModule public verifierModule;
  StorageMirrorRootRegistry public storageMirrorRootRegistry;
  ISafe public safe;
  ISafe public nonHomeChainSafe;

  function setUp() public virtual {
    // Set up both forks
    _mainnetForkId = vm.createSelectFork(vm.rpcUrl('mainnet_e2e'));


    // Fetches all addresses from the deploy script
    storageMirror = StorageMirror(
      vm.parseJsonAddress(vm.readFile('./solidity/scripts/deployments/HomeChainDeployments.json'), '$.StorageMirror')
    );
    updateStorageMirrorGuard = UpdateStorageMirrorGuard(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/HomeChainDeployments.json'), '$.UpdateStorageMirrorGuard'
      )
    );
    guardCallbackModule = GuardCallbackModule(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/HomeChainDeployments.json'), '$.GuardCallbackModule'
      )
    );
    oracle = BlockHeaderOracle(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.BlockHeaderOracle'
      )
    );
    needsUpdateGuard = NeedsUpdateGuard(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.NeedsUpdateGuard'
      )
    );
    verifierModule = VerifierModule(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.VerifierModule'
      )
    );
    storageMirrorRootRegistry = StorageMirrorRootRegistry(
      vm.parseJsonAddress(
        vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.StorageMirrorRootRegistry'
      )
    );
    safe = ISafe(vm.parseJsonAddress(vm.readFile('./solidity/scripts/deployments/E2ESafeDeployments.json'), '$.Safe'));
    nonHomeChainSafe =
      ISafe(vm.parseJsonAddress(vm.readFile('./solidity/scripts/deployments/E2ESafeDeployments.json'), '$.SafeOp'));

    // Save the storage mirror proofs
    saveProof(
      vm.rpcUrl('mainnet_e2e'),
      vm.toString(address(storageMirror)),
      vm.toString((keccak256(abi.encode(address(safe), 0))))
    );
  }

  function saveProof(string memory _rpc, string memory _contractAddress, string memory _storageSlot) public {
    string[] memory _commands = new string[](8);
    _commands[0] = 'yarn';
    _commands[1] = 'proof';
    _commands[2] = '--rpc';
    _commands[3] = _rpc;
    _commands[4] = '--contract';
    _commands[5] = _contractAddress;
    _commands[6] = '--slot';
    _commands[7] = _storageSlot;

    vm.ffi(_commands);
  }

  function getProof()
    public
    returns (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader)
  {
    _storageProof = vm.parseJsonBytes(vm.readFile('./proofs/proof.json'), '$.storageProof');
    _blockHeader = vm.parseJsonBytes(vm.readFile('./proofs/proof.json'), '$.blockHeader');
    _accountProof = vm.parseJsonBytes(vm.readFile('./proofs/proof.json'), '$.accountProof');
  }

  /**
   * @notice Helpers function to convert bytes to bytes32
   *
   * @param _source The bytes to convert
   * @return _result The bytes32 variable
   */
  function _bytesToBytes32(bytes memory _source) internal pure returns (bytes32 _result) {
    // Ensure the source data is 32 bytes or less

    // Sanity check the keccak256() of  the security settings should always fit in 32 bytes
    if (_source.length > 33) revert('cant fit');

    // Copy the data into the bytes32 variable
    assembly {
      _result := mload(add(add(_source, 1), 32))
    }
  }
}
