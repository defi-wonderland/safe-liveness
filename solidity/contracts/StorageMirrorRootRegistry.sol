// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';

/**
 * @title StorageMirrorRootRegistry
 * @notice This contract should accept and store storageRoots of the StorageMirror contract in L1.
 */
contract StorageMirrorRootRegistry is IStorageMirrorRootRegistry {
  /**
   * @notice The address of the StorageMirror contract in Home chain
   */
  address public immutable STORAGE_MIRROR;

  /**
   * @notice The address of the Verifier Module
   */
  IVerifierModule public immutable VERIFIER_MODULE;

  /**
   * @notice The block header oracle
   */
  IBlockHeaderOracle public immutable BLOCK_HEADER_ORACLE;

  /**
   * @notice The latest verified storage root of the StorageMirror contract in Home chain
   */
  bytes32 public latestVerifiedStorageMirrorStorageRoot;

  /**
   * @notice The latest verified block number of the Home chain
   */
  uint256 public latestVerifiedBlockNumber;

  constructor(address _storageMirror, IVerifierModule _verifierModule, IBlockHeaderOracle _blockHeaderOracle) {
    STORAGE_MIRROR = _storageMirror;
    VERIFIER_MODULE = _verifierModule;
    BLOCK_HEADER_ORACLE = _blockHeaderOracle;
  }

  /**
   * @notice Users can use to propose and verify a storage root of the StorageMirror contract in Home chain
   * @dev Calls queryL1BlockHeader to get the block header of the Home chain
   * @dev Call verifier module for the actual verificationn
   * @param _accountProof The account proof of the StorageMirror contract in Home chain
   */
  function proposeAndVerifyStorageMirrorStorageRoot(bytes memory _accountProof) external {
    bytes memory _blockHeader = _queryL1BlockHeader();

    (bytes32 _latestVerifiedStorageMirrorStorageRoot, uint256 _blockNumber) =
      VERIFIER_MODULE.extractStorageMirrorStorageRoot(_accountProof, _blockHeader);

    latestVerifiedStorageMirrorStorageRoot = _latestVerifiedStorageMirrorStorageRoot;
    latestVerifiedBlockNumber = _blockNumber;

    emit VerifiedStorageMirrorStorageRoot(_blockNumber, latestVerifiedStorageMirrorStorageRoot);
  }

  /**
   * @notice Function that queries an oracle to get the latest bridged block header of the Home chain
   * @return _blockHeader The block header of the Home chain
   */
  function _queryL1BlockHeader() internal view returns (bytes memory _blockHeader) {
    (_blockHeader,) = BLOCK_HEADER_ORACLE.getLatestBlockHeader();
  }
}
