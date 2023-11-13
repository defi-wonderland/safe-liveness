// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from '../utils/DSTestFull.sol';
import {GuardCallbackModule, IGuardCallbackModule} from 'contracts/GuardCallbackModule.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

contract FakeSafe {
  address internal constant _SENTINEL_MODULES = address(0x1);
  uint256 internal constant _GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
  address public immutable CALLBACK_MODULE;

  constructor(address _callbackModule) {
    CALLBACK_MODULE = _callbackModule;
    bytes32 _sentinelMappingLocation = keccak256(abi.encode(1, _SENTINEL_MODULES));
    assembly {
      sstore(_sentinelMappingLocation, 0x1)
    }
  }

  function makeDelegateCall(address _guard) external {
    (bool _success,) = CALLBACK_MODULE.delegatecall(abi.encodeWithSignature('setupGuardAndModule(address)', _guard));

    // solhint-disable-next-line
    require(_success);
  }

  function getSentinelModule() external view returns (address _sentinelModule) {
    bytes32 _path = keccak256(abi.encode(1, _SENTINEL_MODULES));
    assembly {
      _sentinelModule := sload(_path)
    }
  }

  function getSavedModule(address _module) external view returns (address _savedModule) {
    bytes32 _path = keccak256(abi.encode(1, _module));
    assembly {
      _savedModule := sload(_path)
    }
  }

  function getGuard() external view returns (address _guard) {
    assembly {
      _guard := sload(_GUARD_STORAGE_SLOT)
    }
  }

  // solhint-disable
  function execTransactionFromModule(
    address _to,
    uint256 _value,
    bytes memory _data,
    Enum.Operation _operation
  ) external virtual returns (bool _success) {
    _success = true;
    // solhint-enable
  }
}

abstract contract Base is DSTestFull {
  address internal _safe = _label('safe');
  address internal _guard = _label('guard');
  address internal _storageMirror = _label('storageMirror');

  GuardCallbackModule internal _guardCallbackModule = new GuardCallbackModule(_storageMirror);
  FakeSafe internal _fakeSafe = new FakeSafe(address(_guardCallbackModule));

  event EnabledModule(address _module);
  event ChangedGuard(address _guard);
}

contract UnitGuardCallbackModuel is Base {
  function testSetupGuardAndModule() public {
    _fakeSafe.makeDelegateCall(_guard);

    assertEq(_guard, _fakeSafe.getGuard(), 'Guard should be saved');
    assertEq(address(_guardCallbackModule), _fakeSafe.getSentinelModule(), 'Sentinel module should be saved');
    assertEq(address(0x1), _fakeSafe.getSavedModule(address(_guardCallbackModule)), 'Module should be saved');
  }

  function testSetupGuardAndModuleRevertsIfNotDelegateCall() public {
    vm.expectRevert(IGuardCallbackModule.OnlyDelegateCall.selector);
    _guardCallbackModule.setupGuardAndModule(_guard);
  }

  function testSetupGuardAndModuleEmitsGuardEvent() public {
    vm.expectEmit(true, true, true, true);
    emit ChangedGuard(_guard);
    _fakeSafe.makeDelegateCall(_guard);
  }

  function testSetupGuardAndModuleEmitsModuleEvent() public {
    vm.expectEmit(true, true, true, true);
    emit EnabledModule(address(_guardCallbackModule));
    _fakeSafe.makeDelegateCall(_guard);
  }

  function testSaveUpdatedSettingsMakesCall() public {
    address[] memory _owners = new address[](1);
    _owners[0] = address(_fakeSafe);
    bytes memory _txData = abi.encodeWithSelector(
      ISafe.execTransactionFromModule.selector,
      _storageMirror,
      0,
      abi.encodeWithSelector(
        IStorageMirror.update.selector, IStorageMirror.SafeSettings({owners: _owners, threshold: 1})
      ),
      Enum.Operation.Call
    );
    vm.expectCall(address(_fakeSafe), _txData);
    _guardCallbackModule.saveUpdatedSettings(
      address(_fakeSafe), IStorageMirror.SafeSettings({owners: _owners, threshold: 1})
    );
  }
}
