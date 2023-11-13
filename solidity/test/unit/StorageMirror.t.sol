// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {StorageMirror} from 'contracts/StorageMirror.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

abstract contract Base is Test {
  event SettingsUpdated(
    address indexed _safe, bytes32 indexed _settingsHash, IStorageMirror.SafeSettings _safeSettings
  );

  address public safe;
  StorageMirror public storageMirror;

  function setUp() public {
    safe = makeAddr('safe');
    storageMirror = new StorageMirror();
  }
}

contract UnitStorageMirror is Base {
  function testUpdate(uint256 _threshold, address _owner) public {
    address[] memory _owners = new address[](1);
    _owners[0] = _owner;

    IStorageMirror.SafeSettings memory _safeSettings =
      IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold});

    vm.prank(safe);
    storageMirror.update(_safeSettings);

    bytes32 _settingsHash = keccak256(abi.encode(_safeSettings));
    bytes32 _savedHash = storageMirror.latestSettingsHash(safe);

    assertEq(_settingsHash, _savedHash, 'Settings hash should be saved');
  }

  function testUpdateEmitsEvent(uint256 _threshold, address _owner) public {
    address[] memory _owners = new address[](1);
    _owners[0] = _owner;

    IStorageMirror.SafeSettings memory _safeSettings =
      IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold});

    bytes32 _expectedSettingsHash = keccak256(abi.encode(_safeSettings));

    vm.prank(safe);
    vm.expectEmit(true, true, true, true);
    emit SettingsUpdated(safe, _expectedSettingsHash, _safeSettings);
    storageMirror.update(_safeSettings);
  }
}
