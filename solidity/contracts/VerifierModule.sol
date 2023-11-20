// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

contract VerifierModule is IVerifierModule {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  address public constant SENTINEL_OWNERS = address(0x1);

  /**
   * @notice The address of the StorageMirrorRootRegistry contract
   */

  address public immutable STORAGE_MIRROR_ROOT_REGISTRY;

  /**
   * @notice The address of the StorageMirror contract on the home chain
   */

  address public immutable STORAGE_MIRROR;

  /**
   * @notice The mapping of the safe to the keccak256 hash of the latest verified settings
   */

  mapping(address => bytes32) public latestVerifiedSettings;

  constructor(address _storageMirrorRootRegistry, address _storageMirror) {
    STORAGE_MIRROR_ROOT_REGISTRY = _storageMirrorRootRegistry;
    STORAGE_MIRROR = _storageMirror;
  }

  function proposeAndVerifyUpdate(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorStorageProof,
    TransactionDetails calldata _transactionDetails
  ) external {
    bytes32 _hashedProposedSettings = _verifyNewSettings(_safe, _proposedSettings, _storageMirrorStorageProof);

    // If we dont revert from the _verifyNewSettings() call, then we can update the safe

    _updateLatestVerifiedSettings(_safe, _proposedSettings);

    ISafe(_safe).execTransaction(
      _transactionDetails.to,
      _transactionDetails.value,
      _transactionDetails.data,
      _transactionDetails.operation,
      _transactionDetails.safeTxGas,
      _transactionDetails.baseGas,
      _transactionDetails.gasPrice,
      _transactionDetails.gasToken,
      _transactionDetails.refundReceiver,
      _transactionDetails.signatures
    );

    // Make the storage updates at the end of the call to save gas in a revert scenario
    latestVerifiedSettings[_safe] = _hashedProposedSettings;

    emit VerifiedUpdate(_safe, _hashedProposedSettings);
  }

  function _verifyNewSettings(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof
  ) internal view virtual returns (bytes32 _hashedProposedSettings) {
    bytes32 _latestStorageRoot = IStorageMirrorRootRegistry(STORAGE_MIRROR_ROOT_REGISTRY).latestVerifiedStorageRoot();

    // The slot of where the latest settings hash is stored in the storage mirror
    bytes32 _safeSettingsSlot = keccak256(abi.encode(_safe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    RLPReader.RLPItem[] memory _stack = _storageMirrorStorageProof.toRlpItem().toList();

    bytes memory _slotValue =
      MerklePatriciaProofVerifier.extractProofValue(_latestStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _stack);

    bytes32 _hashedSavedSettings = _bytesToBytes32(_slotValue);

    _hashedProposedSettings = keccak256(abi.encode(_proposedSettings));

    if (_hashedProposedSettings != _hashedSavedSettings) revert SettingsDontMatch();
  }

  function _updateLatestVerifiedSettings(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings
  ) internal {
    address[] memory _oldOwners = ISafe(_safe).getOwners();
    uint256 _newThreshold = _proposedSettings.threshold;
    address[] memory _newOwners = _proposedSettings.owners;
    bool hasUpdatedThreshold;

    // NOTE: Threshold is automatically updated inside these calls if it needs to be updated
    for (uint256 i; i < _newOwners.length; i++) {
      if (!ISafe(_safe).isOwner(_newOwners[i])) {
        hasUpdatedThreshold = true;
        ISafe(_safe).execTransactionFromModule(
          _safe,
          0,
          abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, _newOwners[i], _newThreshold),
          Enum.Operation.Call
        );
      }
    }

    for (uint256 i; i < _oldOwners.length; i++) {
      if (!_linearSearchOwners(_oldOwners[i], _newOwners)) {
        hasUpdatedThreshold = true;
        ISafe(_safe).execTransactionFromModule(
          _safe,
          0,
          abi.encodeWithSelector(
            ISafe.removeOwner.selector,
            _oldOwners[i],
            int256(i) - 1 < 0 ? SENTINEL_OWNERS : _oldOwners[i - 1],
            _newThreshold
          ),
          Enum.Operation.Call
        );
      }
    }

    // If the threshold has not been updated, then we need to check if it needs to be updated
    if (!hasUpdatedThreshold) {
      uint256 _oldThreshold = ISafe(_safe).getThreshold();

      if (_oldThreshold != _newThreshold) {
        ISafe(_safe).execTransactionFromModule(
          _safe, 0, abi.encodeWithSelector(ISafe.changeThreshold.selector, _newThreshold), Enum.Operation.Call
        );
      }
    }
  }

  function _linearSearchOwners(address _owner, address[] memory _owners) internal pure returns (bool _result) {
    for (uint256 i; i < _owners.length; i++) {
      if (_owners[i] == _owner) {
        _result = true;
        break;
      }
    }
  }

  function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
    // Ensure the source data is 32 bytes or less

    // Sanity check the keccak256() of  the security settings should always fit in 32 bytes
    if (source.length > 32) revert BytesToBytes32Failed();

    // Copy the data into the bytes32 variable
    assembly {
      result := mload(add(source, 32))
    }
  }
}
