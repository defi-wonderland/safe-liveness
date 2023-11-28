// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {Safe} from 'safe-contracts/Safe.sol';

import {DeployHomeChain, DeployVars} from 'scripts/DeployHomeChain.s.sol';
import {DeployNonHomeChain, DeployVarsNonHomeChain} from 'scripts/DeployNonHomeChain.s.sol';
import {TestConstants} from 'test/utils/TestConstants.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IGnosisSafeProxyFactory} from 'test/integration/IGnosisSafeProxyFactory.sol';

struct Signature {
  uint8 v;
  bytes32 r;
  bytes32 s;
}

contract DeployIntegration is Script, DeployHomeChain, DeployNonHomeChain {
  address internal _deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));
  uint256 internal _pk = vm.envUint('MAINNET_DEPLOYER_PK');
  address[] internal _owners = [_deployer];
  Safe internal _singletonSafe;
  Safe internal _singletonSafeOp;
  IVerifierModule.SafeTxnParams internal _vars;

  function run() external {
    vm.createSelectFork(vm.rpcUrl('mainnet_integration'));
    vm.startBroadcast(_deployer);

    _singletonSafe = new Safe();
    DeployVars memory _deployVarsHomeChain = DeployVars(_deployer);

    // Deploy protocol
    _deployHomeChain(_deployVarsHomeChain);
    ISafe _safe = ISafe(address(new SafeProxy(address(_singletonSafe))));
    address _storageMirrorAddr =
      vm.parseJsonAddress(vm.readFile('./solidity/scripts/deployments/HomeChainDeployments.json'), '$.StorageMirror');

    _setupHomeChain(_safe, _storageMirrorAddr);

    DeployVarsNonHomeChain memory _deployVarsNonHomeChain = DeployVarsNonHomeChain(_deployer, _storageMirrorAddr);

    // Deploy protocol
    _deployNonHomeChain(_deployVarsNonHomeChain);

    address _verifierModule = vm.parseJsonAddress(
      vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.VerifierModule'
    );

    _setupNonHomeChain(_safe, _verifierModule);

    vm.stopBroadcast();

    string memory _objectKey = 'deployments';

    vm.serializeAddress(_objectKey, 'Safe', address(_safe));

    string memory _output = vm.serializeAddress(_objectKey, 'SafeOp', address(_safe));

    vm.writeJson(_output, './solidity/scripts/deployments/IntegrationSafeDeployments.json');
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

    address _guardCallbackModule = vm.parseJsonAddress(
      vm.readFile('./solidity/scripts/deployments/HomeChainDeployments.json'), '$.GuardCallbackModule'
    );

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

    Signature memory _signature;

    // signature
    (_signature.v, _signature.r, _signature.s) = vm.sign(_pk, keccak256(_txData));

    _vars = IVerifierModule.SafeTxnParams({
      to: address(_guardCallbackModule),
      value: 0,
      data: abi.encodeWithSelector(IGuardCallbackModule.setGuard.selector),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: abi.encodePacked(_signature.r, _signature.s, _signature.v)
    });

    _safe.execTransaction(
      _vars.to,
      _vars.value,
      _vars.data,
      _vars.operation,
      _vars.safeTxGas,
      _vars.baseGas,
      _vars.gasPrice,
      _vars.gasToken,
      _vars.refundReceiver,
      _vars.signatures
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
    (_signature.v, _signature.r, _signature.s) = vm.sign(_pk, keccak256(_txData));

    _vars.to = _storageMirrorAddr;
    _vars.data = abi.encodeWithSelector(IStorageMirror.update.selector, keccak256(abi.encode(_owners, 1)));
    _vars.signatures = abi.encodePacked(_signature.r, _signature.s, _signature.v);

    // execute update storage mirror
    _safe.execTransaction(
      _vars.to,
      _vars.value,
      _vars.data,
      _vars.operation,
      _vars.safeTxGas,
      _vars.baseGas,
      _vars.gasPrice,
      _vars.gasToken,
      _vars.refundReceiver,
      _vars.signatures
    );
  }

  function _setupNonHomeChain(ISafe _safe, address _verifierModule) internal {
    enableModule(_safe, _pk, _verifierModule);

    address _needsUpdateGuard = vm.parseJsonAddress(
      vm.readFile('./solidity/scripts/deployments/NonHomeChainDeployments.json'), '$.NeedsUpdateGuard'
    );

    // data to sign and send to set the guard
    bytes memory _txData = _safe.encodeTransactionData(
      address(_safe),
      0,
      abi.encodeWithSelector(ISafe.setGuard.selector, _needsUpdateGuard),
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      _safe.nonce()
    );

    Signature memory _signature;

    // signature
    (_signature.v, _signature.r, _signature.s) = vm.sign(_pk, keccak256(_txData));

    _vars = IVerifierModule.SafeTxnParams({
      to: address(_safe),
      value: 0,
      data: abi.encodeWithSelector(ISafe.setGuard.selector, _needsUpdateGuard),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: abi.encodePacked(_signature.r, _signature.s, _signature.v)
    });

    _safe.execTransaction(
      _vars.to,
      _vars.value,
      _vars.data,
      _vars.operation,
      _vars.safeTxGas,
      _vars.baseGas,
      _vars.gasPrice,
      _vars.gasToken,
      _vars.refundReceiver,
      _vars.signatures
    );
  }
}
