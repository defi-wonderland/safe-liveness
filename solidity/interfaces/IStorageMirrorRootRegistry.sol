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

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The function that updates the latest verified storage root
   * @dev This function can only be called by the VerifierModule contract
   * @param _storageRoot The storage root to be stored
   */

  function storeLatestStorageMirrorStorageRoot(bytes32 _storageRoot, uint256 _timestamp) external;

  /**
   * @notice The function that queries the latest L1 block header
   */

  function getLatestBlockHeader() external view returns (bytes memory _blockHeader, uint256 _blockTimestamp);
}
