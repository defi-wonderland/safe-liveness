// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

import {StorageMirror} from 'contracts/StorageMirror.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {GuardCallbackModule} from 'contracts/GuardCallbackModule.sol';
import {BlockHeaderOracle} from 'contracts/BlockHeaderOracle.sol';
import {NeedsUpdateGuard} from 'contracts/NeedsUpdateGuard.sol';

import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

import {IGnosisSafeProxyFactory} from 'test/e2e/IGnosisSafeProxyFactory.sol';
import {TestConstants} from 'test/utils/TestConstants.sol';
import {ContractDeploymentAddress} from 'test/utils/ContractDeploymentAddress.sol';

contract CommonE2EBase is DSTestPlus, TestConstants {
  uint256 internal constant _FORK_BLOCK = 15_452_788;

  address public deployer = makeAddr('deployer');
  address public proposer = makeAddr('proposer');
  address public safeOwner;
  uint256 public safeOwnerKey;

  address public nonHomeChainSafeOwner;
  uint256 public nonHomeChainSafeOwnerKey;

  StorageMirror public storageMirror;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;
  GuardCallbackModule public guardCallbackModule;
  BlockHeaderOracle public oracle;
  NeedsUpdateGuard public needsUpdateGuard;
  ISafe public safe;
  ISafe public nonHomeChainSafe;
  IVerifierModule public verifierModule = IVerifierModule(makeAddr('verifierModule'));
  IGnosisSafeProxyFactory public gnosisSafeProxyFactory = IGnosisSafeProxyFactory(GNOSIS_SAFE_PROXY_FACTORY);

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);

    // Make address and key of safe owner
    (safeOwner, safeOwnerKey) = makeAddrAndKey('safeOwner');
    // Make address and key of non home chain safe owner
    (nonHomeChainSafeOwner, nonHomeChainSafeOwnerKey) = makeAddrAndKey('nonHomeChainSafeOwner');

    /// =============== HOME CHAIN ===============
    vm.prank(safeOwner);
    safe = ISafe(address(gnosisSafeProxyFactory.createProxy(GNOSIS_SAFE_SINGLETON, ''))); // safeOwner nonce 0
    label(address(safe), 'SafeProxy');

    address _updateStorageMirrorGuardTheoriticalAddress = ContractDeploymentAddress.addressFrom(deployer, 2);

    vm.prank(deployer);
    storageMirror = new StorageMirror(); // deployer nonce 0
    label(address(storageMirror), 'StorageMirror');

    vm.prank(deployer);
    guardCallbackModule = new GuardCallbackModule(address(storageMirror), _updateStorageMirrorGuardTheoriticalAddress); // deployer nonce 1
    label(address(guardCallbackModule), 'GuardCallbackModule');

    vm.prank(deployer);
    updateStorageMirrorGuard = new UpdateStorageMirrorGuard(guardCallbackModule); // deployer nonce 2
    label(address(updateStorageMirrorGuard), 'UpdateStorageMirrorGuard');

    // Make sure the theoritical address was calculated correctly
    assert(address(updateStorageMirrorGuard) == _updateStorageMirrorGuardTheoriticalAddress);

    // Set up owner home chain safe
    address[] memory _owners = new address[](1);
    _owners[0] = safeOwner;
    vm.prank(safeOwner); // safeOwner nonce 1
    safe.setup(_owners, 1, address(safe), bytes(''), address(0), address(0), 0, payable(0));

    // Enable guard callback module
    enableModule(safe, safeOwner, safeOwnerKey, address(guardCallbackModule));

    // data to sign and send to set the guard
    bytes memory _setGuardData = abi.encodeWithSelector(IGuardCallbackModule.setGuard.selector);
    bytes memory _setGuardEncodedTxData = safe.encodeTransactionData(
      address(guardCallbackModule), 0, _setGuardData, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), safe.nonce()
    );

    // signature
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(safeOwnerKey, keccak256(_setGuardEncodedTxData));
    bytes memory _setGuardSignature = abi.encodePacked(_r, _s, _v);

    // execute setup of guard
    vm.prank(safeOwner);
    safe.execTransaction(
      address(guardCallbackModule),
      0,
      _setGuardData,
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      _setGuardSignature
    );

    /// =============== NON HOME CHAIN ===============
    // Set up non home chain safe
    vm.prank(nonHomeChainSafeOwner);
    nonHomeChainSafe = ISafe(address(gnosisSafeProxyFactory.createProxy(GNOSIS_SAFE_SINGLETON, ''))); // nonHomeChainSafeOwner nonce 0
    label(address(nonHomeChainSafe), 'NonHomeChainSafeProxy');

    // Deploy non home chain contracts
    vm.prank(deployer);
    oracle = new BlockHeaderOracle(); // deployer nonce 3
    label(address(oracle), 'MockOracle');

    // vm.prank(deployer);
    // verifierModule = new VerifierModule(..); // deployer nonce 4
    // label(address(verifierModule), 'VerifierModule');

    vm.prank(deployer);
    needsUpdateGuard = new NeedsUpdateGuard(verifierModule); // deployer nonce 5
    label(address(needsUpdateGuard), 'NeedsUpdateGuard');

    // set up non home chain safe
    address[] memory _nonHomeChainSafeOwners = new address[](1);
    _nonHomeChainSafeOwners[0] = nonHomeChainSafeOwner;
    vm.prank(nonHomeChainSafeOwner); // nonHomeChainSafeOwner nonce 1
    nonHomeChainSafe.setup(
      _nonHomeChainSafeOwners, 1, address(nonHomeChainSafe), bytes(''), address(0), address(0), 0, payable(0)
    );

    // enable verifier module

    // set needs update guard
  }

  /**
   * @notice Enables a module for the given safe
   * @param _safe The safe that will enable the module
   * @param _safeOwner The address of the owner of the safe
   * @param _safeOwnerKey The private key to sign the tx
   * @param _module The module address to enable
   */
  function enableModule(ISafe _safe, address _safeOwner, uint256 _safeOwnerKey, address _module) public {
    uint256 _safeNonce = _safe.nonce();
    // data to sign to enable module
    bytes memory _enableModuleData = abi.encodeWithSelector(ISafe.enableModule.selector, address(_module));
    bytes memory _enableModuleEncodedTxData = _safe.encodeTransactionData(
      address(_safe), 0, _enableModuleData, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), _safeNonce
    );

    // signature
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_safeOwnerKey, keccak256(_enableModuleEncodedTxData));
    bytes memory _enableModuleSignature = abi.encodePacked(_r, _s, _v);

    // execute enable module
    vm.prank(_safeOwner);
    _safe.execTransaction(
      address(_safe), 0, _enableModuleData, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), _enableModuleSignature
    );
  }
}
