// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IStorageMirrorRootRegistry {
  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The latest verified storage root
   */
  function latestVerifiedStorageRoot() external view returns (bytes32 _latestVerifiedStorageRoot);
}
