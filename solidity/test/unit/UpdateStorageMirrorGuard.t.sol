// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import 'forge-std/Test.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';

abstract contract Base is Test {
  address public safe;
  IGuardCallbackModule public guardCallbackModule;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;

  bytes32 public immutable SETTINGS_HASH = keccak256(abi.encodePacked('settings'));

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

    vm.prank(safe);
    updateStorageMirrorGuard.checkTransaction(
      address(0), 0, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', address(0)
    );

    assertTrue(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), keccak256(abi.encodePacked('settings')));
  }

  function testCheckAfterExecution(bytes32 _txHash) public {
    // Call checkTransaction to change didSettingsChange to true
    vm.prank(safe);
    updateStorageMirrorGuard.checkTransaction(
      address(0), 0, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', address(0)
    );

    vm.mockCall(
      address(guardCallbackModule),
      abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, SETTINGS_HASH)),
      abi.encode()
    );
    vm.expectCall(
      address(guardCallbackModule), abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, SETTINGS_HASH))
    );
    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, true);

    assertFalse(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), keccak256(abi.encodePacked('')));
  }

  function testCheckAfterExecutionNoSettingsChange(bytes32 _txHash) public {
    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, true);

    assertFalse(updateStorageMirrorGuard.didSettingsChange());
    assertEq(updateStorageMirrorGuard.settingsHash(), bytes32(''));
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
    assertEq(updateStorageMirrorGuard.settingsHash(), keccak256(abi.encodePacked('settings')));
  }
}
