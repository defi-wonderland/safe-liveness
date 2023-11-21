// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

interface IGuardCallbackModule {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

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

  /**
   * @notice The address of the UpdateStorageMirrorGuard contract.
   */
  function GUARD() external view returns (address _guard);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Saves the updated settings for the safe to the StorageMirror.
   * @dev Executes a transaction from the module to update the safe settings in the StorageMirror.
   * @param _safe The address of the safe.
   * @param _safeSettings The settings of the safe.
   */
  function saveUpdatedSettings(address _safe, IStorageMirror.SafeSettings memory _safeSettings) external;

  /**
   * @notice Initates the module by setting the guard.
   */
  function setGuard() external;
}
