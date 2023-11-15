// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

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
   * @param _settingsHash The hash of the new settings for the safe.
   */

  function saveUpdatedSettings(address _safe, bytes32 _settingsHash) external;
}
