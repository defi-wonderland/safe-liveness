// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IVerifierModule {
  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The timestamp when the latest settings were verified
   * @param _safe The address of the safe
   * @return _timestamp The timestamp
   */
  function latestVerifiedSettingsTimestamp(address _safe) external view returns (uint256 _timestamp);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  function extractStorageMirrorStorageRoot(
    bytes memory _blockHeader,
    bytes memory _accountProof
  ) external view returns (bytes32 _storageRoot, uint256 _blockNumber);
}
