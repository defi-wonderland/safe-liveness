// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';

/**
 * @title GuardCallbackModule
 * @notice This contract is a module that is used to save the updated settings to the StorageMirror.
 * @dev It can also be used to set the guard and module in one transaction.
 */
contract GuardCallbackModule is IGuardCallbackModule {
  address public immutable STORAGE_MIRROR;
  address public immutable GUARD;

  constructor(address _storageMirror, address _guard) {
    STORAGE_MIRROR = _storageMirror;
    GUARD = _guard;
  }

  /**
   * @notice Initates the module by setting the guard.
   *
   * @param _safe The address of the safe.
   */

  function init(address _safe) external {
    ISafe(_safe).execTransactionFromModule(
      _safe, 0, abi.encodeWithSelector(ISafe.setGuard.selector, GUARD), Enum.Operation.Call
    );
  }

  /**
   * @notice Saves the updated settings for the safe to the StorageMirror.
   * @dev Executes a transaction from the module to update the safe settings in the StorageMirror.
   * @param _safe The address of the safe.
   * @param _settingsHash The hash of the new settings for the safe.
   */

  function saveUpdatedSettings(address _safe, bytes32 _settingsHash) external {
    if (msg.sender != GUARD) revert OnlyGuard();
    bytes memory _txData = abi.encodeWithSelector(IStorageMirror.update.selector, _settingsHash);
    ISafe(_safe).execTransactionFromModule(STORAGE_MIRROR, 0, _txData, Enum.Operation.Call);
  }
}
