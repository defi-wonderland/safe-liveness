// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from '../utils/DSTestFull.sol';
import {StorageMirror} from 'contracts/StorageMirror.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

abstract contract Base is DSTestFull {
  address internal _safe = _label('safe');

  StorageMirror internal _storageMirror = new StorageMirror();

  event SettingsUpdated(
    address indexed _safe, bytes32 indexed _settingsHash, IStorageMirror.SafeSettings _safeSettings
  );
}

contract UnitStorageMirror is Base {
  function testUpdate(uint256 _threshold, address _owner) public {
    address[] memory _owners = new address[](1);
    _owners[0] = _owner;

    IStorageMirror.SafeSettings memory _safeSettings =
      IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold});

    vm.prank(_safe);
    _storageMirror.update(_safeSettings);

    bytes32 _settingsHash = keccak256(abi.encode(_safeSettings));
    bytes32 _savedHash = _storageMirror.latestSettingsHash(_safe);

    assertEq(_settingsHash, _savedHash, 'Settings hash should be saved');
  }

  function testUpdateEmitsEvent(uint256 _threshold, address _owner) public {
    address[] memory _owners = new address[](1);
    _owners[0] = _owner;

    IStorageMirror.SafeSettings memory _safeSettings =
      IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold});

    bytes32 _expectedSettingsHash = keccak256(abi.encode(_safeSettings));

    vm.prank(_safe);
    vm.expectEmit(true, true, true, true);
    emit SettingsUpdated(_safe, _expectedSettingsHash, _safeSettings);
    _storageMirror.update(_safeSettings);
  }
}
