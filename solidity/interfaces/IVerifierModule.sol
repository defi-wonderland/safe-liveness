// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

interface IVerifierModule {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  event VerifiedUpdate(address safe, bytes32 verifiedHash);

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

  struct TransactionDetails {
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
   */

  function STORAGE_MIRROR() external view returns (address _storageMirror);

  /**
   * @notice The address of the StorageMirrorRootRegistry contract.
   */

  function STORAGE_MIRROR_ROOT_REGISTRY() external view returns (address _storageMirrorRootRegistry);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  function proposeAndVerifyUpdate(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof,
    TransactionDetails calldata _transactionDetails
  ) external;
}
