// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {GuardCallbackModule, IGuardCallbackModule} from 'contracts/GuardCallbackModule.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

contract FakeSafe {
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

abstract contract Base is Test {
  address internal _guard = makeAddr('guard');
  address internal _storageMirror = makeAddr('storageMirror');

  GuardCallbackModule internal _guardCallbackModule = new GuardCallbackModule(_storageMirror, _guard);
  FakeSafe internal _fakeSafe = new FakeSafe();

  event EnabledModule(address _module);
  event ChangedGuard(address _guard);
}

contract UnitGuardCallbackModuel is Base {
  function testSetGuard() public {
    bytes memory _txData = abi.encodeWithSelector(
      ISafe.execTransactionFromModule.selector,
      address(_fakeSafe),
      0,
      abi.encodeWithSelector(ISafe.setGuard.selector, _guard),
      Enum.Operation.Call
    );
    vm.prank(address(_fakeSafe));
    vm.expectCall(address(_fakeSafe), _txData);
    _guardCallbackModule.setGuard();
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
    vm.prank(_guard);
    vm.expectCall(address(_fakeSafe), _txData);
    _guardCallbackModule.saveUpdatedSettings(
      address(_fakeSafe), IStorageMirror.SafeSettings({owners: _owners, threshold: 1})
    );
  }

  function testSaveUpdatedSettingsRevertsIfNotCalledFromGuard(IStorageMirror.SafeSettings memory _safeSettings) public {
    vm.expectRevert(IGuardCallbackModule.OnlyGuard.selector);
    _guardCallbackModule.saveUpdatedSettings(address(_fakeSafe), _safeSettings);
  }
}
