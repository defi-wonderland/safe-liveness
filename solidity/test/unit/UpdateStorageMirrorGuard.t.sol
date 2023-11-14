// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

abstract contract Base is Test {
  event SettingsChanged(address indexed _safe, bytes32 indexed _settingsHash, IStorageMirror.SafeSettings _settings);

  address public safe;
  IGuardCallbackModule public guardCallbackModule;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;

  address[] public owners = new address[](1);
  IStorageMirror.SafeSettings public safeSettings = IStorageMirror.SafeSettings({owners: owners, threshold: 1});
  bytes32 public settingsHash = keccak256(abi.encode(safeSettings));

  function setUp() public {
    safe = makeAddr('safe');
    guardCallbackModule = IGuardCallbackModule(makeAddr('guardCallbackModule'));
    updateStorageMirrorGuard = new UpdateStorageMirrorGuard(guardCallbackModule);
  }
}

contract UnitUpdateStorageMirrorGuard is Base {
  function testCheckTransaction() public {
    assertFalse(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), bytes32(''));

    vm.expectEmit(true, true, true, true);
    emit SettingsChanged(safe, settingsHash, safeSettings);
    vm.prank(safe);
    updateStorageMirrorGuard.checkTransaction(
      address(0), 0, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', address(0)
    );

    assertTrue(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), settingsHash, 'Settings hash should be stored');
  }

  function testCheckAfterExecution(bytes32 _txHash) public {
    // Call checkTransaction to change didSettingsChange to true
    vm.prank(safe);
    updateStorageMirrorGuard.checkTransaction(
      address(0), 0, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', address(0)
    );

    vm.mockCall(
      address(guardCallbackModule),
      abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, settingsHash)),
      abi.encode()
    );
    vm.expectCall(
      address(guardCallbackModule), abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, settingsHash))
    );
    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, true);

    assertFalse(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), keccak256(abi.encodePacked('')), 'Settings hash should reset');
  }

  function testCheckAfterExecutionNoSettingsChange(bytes32 _txHash) public {
    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, true);

    assertFalse(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), bytes32(''), 'Settings hash should stay empty');
  }

  function testCheckAfterExecutionTxFailed(bytes32 _txHash) public {
    // Call checkTransaction to change didSettingsChange to true
    vm.prank(safe);
    updateStorageMirrorGuard.checkTransaction(
      address(0), 0, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', address(0)
    );

    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, false);

    // Should be true since the tx failed to execute and thus didnt make it to reset
    assertTrue(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), settingsHash, 'Settings hash should stay the same');
  }
}
