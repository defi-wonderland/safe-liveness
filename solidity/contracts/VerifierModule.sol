// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

contract VerifierModule is IVerifierModule {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

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
    uint256 _updateNonce,
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof
  ) external {
    bytes32 _hashedProposedSettings = _verifyNewSettings(_safe, _proposedSettings, _storageMirrorStorageProof);

    // If we dont revert from the _verifyNewSettings() call, then we can update the safe

    // TODO: Update safe with the new settings
    // TODO: Pay incentives
  }

  function _verifyNewSettings(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof
  ) internal view returns (bytes32 _hashedProposedSettings) {
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
  ) internal {}

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
