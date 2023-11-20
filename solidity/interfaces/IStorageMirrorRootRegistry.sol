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
   * @notice Users can use to propose and verify a storage root of the StorageMirror contract in Home chain
   * @dev Calls queryL1BlockHeader to get the block header of the Home chain
   * @dev Call verifier module for the actual verificationn
   * @param _accountProof The account proof of the StorageMirror contract in Home chain
   */
  function proposeAndVerifyStorageMirrorStorageRoot(bytes memory _accountProof) external;
}
