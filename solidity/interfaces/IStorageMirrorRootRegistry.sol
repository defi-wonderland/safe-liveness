// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';

interface IStorageMirrorRootRegistry {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emits after the storage root gets verified
   * @param _homeChainBlockNumber The block number of the Home chain
   * @param _storageRoot The storage root of the StorageMirror contract in Home chain that was verified
   */
  event VerifiedStorageMirrorStorageRoot(uint256 indexed _homeChainBlockNumber, bytes32 _storageRoot);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The address of the StorageMirror contract in Home chain
   * @return _storageMirror The address of the StorageMirror contract in Home chain
   */
  function STORAGE_MIRROR() external view returns (address _storageMirror);

  /**
   * @notice The address of the Verifier Module
   * @return _verifierModule The address of the Verifier Module
   */
  function VERIFIER_MODULE() external view returns (IVerifierModule _verifierModule);

  /**
   * @notice The address of the Block Header Oracle
   * @return _blockHeaderOracle The address of the Block Header Oracle
   */
  function BLOCK_HEADER_ORACLE() external view returns (IBlockHeaderOracle _blockHeaderOracle);

  /**
   * @notice The latest verified storage root of the StorageMirror contract in Home chain
   * @return _latestVerifiedStorageMirrorStorageRoot The latest verified storage root of the StorageMirror contract in Home chain
   */
  function latestVerifiedStorageMirrorStorageRoot()
    external
    view
    returns (bytes32 _latestVerifiedStorageMirrorStorageRoot);

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
