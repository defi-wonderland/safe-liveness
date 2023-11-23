// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

import {DeployHomeChain, DeployVars} from 'scripts/DeployHomeChain.s.sol';
import {DeployNonHomeChain, DeployVarsNonHomeChain} from 'scripts/DeployNonHomeChain.s.sol';
import {TestConstants} from 'test/utils/TestConstants.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IGnosisSafeProxyFactory} from 'test/e2e/IGnosisSafeProxyFactory.sol';

contract DeployE2E is Script, DeployHomeChain, DeployNonHomeChain {
  address internal _deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));
  uint256 internal _pk = vm.envUint('MAINNET_DEPLOYER_PK');
  IGnosisSafeProxyFactory public gnosisSafeProxyFactory = IGnosisSafeProxyFactory(GNOSIS_SAFE_PROXY_FACTORY);
  address[] internal _owners = [_deployer];

  function run() external {
    vm.createSelectFork(vm.rpcUrl('mainnet_e2e'));
    vm.startBroadcast(_deployer);
    DeployVars memory _deployVarsHomeChain = DeployVars(_deployer);

    // Deploy protocol
    _deployHomeChain(_deployVarsHomeChain);
    ISafe _safe = ISafe(address(gnosisSafeProxyFactory.createProxy(GNOSIS_SAFE_SINGLETON, '')));
    address _storageMirrorAddr =
      vm.parseJsonAddress(vm.readFile('./solidity/scripts/HomeChainDeployments2.json'), '$.StorageMirror');

    _setupHomeChain(_safe, _storageMirrorAddr);

    vm.stopBroadcast();

    DeployVarsNonHomeChain memory _deployVarsNonHomeChain = DeployVarsNonHomeChain(_deployer, _storageMirrorAddr);

    vm.createSelectFork(vm.rpcUrl('optimism_e2e'));
    vm.startBroadcast(_deployer);

    // Deploy protocol
    _deployNonHomeChain(_deployVarsNonHomeChain);

    vm.stopBroadcast();
  }

  /**
   * @notice Enables a module for the given safe
   * @param _safe The safe that will enable the module
   * @param _safeOwnerKey The private key to sign the tx
   * @param _module The module address to enable
   */
  function enableModule(ISafe _safe, uint256 _safeOwnerKey, address _module) public {
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
    _safe.execTransaction(
      address(_safe), 0, _enableModuleData, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), _enableModuleSignature
    );
  }

  function _setupHomeChain(ISafe _safe, address _storageMirrorAddr) internal {
    _safe.setup(_owners, 1, address(_safe), bytes(''), address(0), address(0), 0, payable(address(0)));

    address _guardCallbackModule =
      vm.parseJsonAddress(vm.readFile('./solidity/scripts/HomeChainDeployments.json'), '$.GuardCallbackModule');

    enableModule(_safe, _pk, _guardCallbackModule);

    // data to sign and send to set the guard
    bytes memory _txData = _safe.encodeTransactionData(
      _guardCallbackModule,
      0,
      abi.encodeWithSelector(IGuardCallbackModule.setGuard.selector),
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      _safe.nonce()
    );

    // signature
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_pk, keccak256(_txData));

    _safe.execTransaction(
      _guardCallbackModule,
      0,
      abi.encodeWithSelector(IGuardCallbackModule.setGuard.selector),
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      abi.encodePacked(_r, _s, _v)
    );

    _txData = _safe.encodeTransactionData(
      _storageMirrorAddr,
      0,
      abi.encodeWithSelector(IStorageMirror.update.selector, keccak256(abi.encode(_owners, 1))),
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      _safe.nonce()
    );

    // signature
    (_v, _r, _s) = vm.sign(_pk, keccak256(_txData));

    // execute update storage mirror
    _safe.execTransaction(
      _storageMirrorAddr,
      0,
      abi.encodeWithSelector(IStorageMirror.update.selector, keccak256(abi.encode(_owners, 1))),
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      abi.encodePacked(_r, _s, _v)
    );
  }
}
