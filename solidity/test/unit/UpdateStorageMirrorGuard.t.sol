// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

abstract contract Base is Test {
  event SettingsChanged(address indexed _safe, bytes32 indexed _settingsHash, IStorageMirror.SafeSettings _settings);

  address public safe;
  IGuardCallbackModule public guardCallbackModule;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;

  address[] public owners = new address[](1);
  IStorageMirror.SafeSettings public safeSettings;
  bytes32 public settingsHash;

  function setUp() public {
    safe = makeAddr('safe');
    guardCallbackModule = IGuardCallbackModule(makeAddr('guardCallbackModule'));
    updateStorageMirrorGuard = new UpdateStorageMirrorGuard(guardCallbackModule);

    owners[0] = safe;
    safeSettings = IStorageMirror.SafeSettings({owners: owners, threshold: 1});
    settingsHash = keccak256(abi.encode(safeSettings));
  }
}

contract UnitUpdateStorageMirrorGuard is Base {
  function testCheckAfterExecution(bytes32 _txHash) public {
    vm.mockCall(
      address(guardCallbackModule),
      abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, settingsHash)),
      abi.encode()
    );
    vm.expectCall(
      address(guardCallbackModule), abi.encodeCall(IGuardCallbackModule.saveUpdatedSettings, (safe, settingsHash))
    );

    vm.expectEmit(true, true, true, true);
    emit SettingsChanged(safe, settingsHash, safeSettings);
    vm.prank(safe);
    updateStorageMirrorGuard.checkAfterExecution(_txHash, true);
  }
}
