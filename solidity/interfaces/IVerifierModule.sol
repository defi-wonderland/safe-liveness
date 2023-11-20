// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

interface IVerifierModule {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  event VerifiedUpdate(address _safe, bytes32 _verifiedHash);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Reverts when the proposed settings dont match the saved settings on the StorageMirror
   */
  error SettingsDontMatch();

  /**
   * @notice Reverts when the bytes cannot be converted to bytes32
   */

  error BytesToBytes32Failed();

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  struct SafeTxnParams {
    address to;
    uint256 value;
    bytes data;
    Enum.Operation operation;
    uint256 safeTxGas;
    uint256 baseGas;
    uint256 gasPrice;
    address gasToken;
    address payable refundReceiver;
    bytes signatures;
  }

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The address of the StorageMirror contract on L1.
   *
   * @return _storageMirror The address of the StorageMirror contract.
   */

  function STORAGE_MIRROR() external view returns (address _storageMirror);

  /**
   * @notice The address of the StorageMirrorRootRegistry contract.
   *
   * @return _storageMirrorRootRegistry The interface of the StorageMirrorRootRegistry contract.
   */

  function STORAGE_MIRROR_ROOT_REGISTRY() external view returns (IStorageMirrorRootRegistry _storageMirrorRootRegistry);

  /**
   * @notice The interface of the BlockHeaderOracle contract.
   *
   * @return _blockHeaderOracle The interface of the BlockHeaderOracle contract.
   */

  function BLOCK_HEADER_ORACLE() external view returns (IBlockHeaderOracle _blockHeaderOracle);

  /**
   * @notice The hash of the latest verified settings for a given safe
   * @param _safe The address of the safe
   *
   * @return _latestVerifiedSettings The hash of the latest verified settings
   */

  function latestVerifiedSettings(address _safe) external view returns (bytes32 _latestVerifiedSettings);

  /**
   * @notice The timestamp for when the settings were last updated for a given safe
   * @param _safe The address of the safe
   *
   * @return _timestamp The timestamp of when it was saved
   */

  function latestVerifiedSettingsTimestamp(address _safe) external view returns (uint256 _timestamp);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The function extracts the storage root of the StorageMirror contract from a given account proof
   *
   * @param _storageMirrorAccountProof The account proof of the StorageMirror contract from the latest block
   */

  function extractStorageMirrorStorageRoot(bytes memory _storageMirrorAccountProof)
    external
    view
    returns (bytes32 _storageRoot);

  /**
   * @notice Verifies the new settings that are incoming against a storage proof from the StorageMirror on the home chain
   *
   * @param _safe The address of the safe that has new settings
   * @param _proposedSettings The new settings that are being proposed
   * @param _storageMirrorStorageProof The storage proof of the StorageMirror contract on the home chain
   * @param _arbitraryTxnParams The transaction parameters for the arbitrary safe transaction that will execute
   */

  function proposeAndVerifyUpdate(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof,
    SafeTxnParams calldata _arbitraryTxnParams
  ) external;

  /**
   * @notice Sets the storage mirror storage root in the registry, verifies it, and then updates the safe in one call
   *
   * @param _safe The address of the safe that has new settings
   * @param _proposedSettings The new settings that are being proposed
   * @param _storageMirrorAccountProof The account proof of the StorageMirror contract on the home chain
   * @param _storageMirrorStorageProof The storage proof of the StorageMirror contract on the home chain
   * @param _arbitraryTxnParams The transaction parameters for the arbitrary safe transaction that will execute
   */

  function extractStorageRootAndVerifyUpdate(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorAccountProof,
    bytes memory _storageMirrorStorageProof,
    SafeTxnParams calldata _arbitraryTxnParams
  ) external;
}
