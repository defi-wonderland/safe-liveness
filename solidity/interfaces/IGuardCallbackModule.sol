// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

interface IGuardCallbackModule {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emits when the module has been enabled
   * @dev This event is copied from the safe to emit in the context of a delegatecall
   * @param _module The address of the module
   */
  event EnabledModule(address _module);

  /**
   * @notice Emits when the guard has been changed
   * @dev This event is copied from the safe to emit in the context of a delegatecall
   * @param _guard The address of the guard
   */

  event ChangedGuard(address _guard);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Reverts when a function is called with call instead of delegatecall
   */

  error OnlyDelegateCall();

  /**
   * @notice Reverts when a function is called from an address that isnt the guard
   */
  error OnlyGuard();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The address of the StorageMirror contract.
   */

  function STORAGE_MIRROR() external view returns (address _storageMirror);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sets up the guard and module for the safe in one transaction.
   * @dev This function can only be called with a delegatecall from a safe.
   */

  function setupGuardAndModule() external;

  /**
   * @notice Saves the updated settings for the safe to the StorageMirror.
   * @dev Executes a transaction from the module to update the safe settings in the StorageMirror.
   * @param _safe The address of the safe.
   * @param _safeSettings The new settings for the safe.
   */

  function saveUpdatedSettings(address _safe, IStorageMirror.SafeSettings memory _safeSettings) external;
}
