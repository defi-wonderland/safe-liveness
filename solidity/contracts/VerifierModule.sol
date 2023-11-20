// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';

/**
 * @title VerifierModule
 * @notice This contract is the verifier module that verifies the settings of a safe against the StorageMirror on the home chain
 */
contract VerifierModule is IVerifierModule {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  /**
   * @notice The start of the linked list for the owners of a safe
   * @dev Used for updating the owners of a safe
   */

  address internal constant _SENTINEL_OWNERS = address(0x1);

  /**
   * @notice The slot of the mapping of the safe to the keccak256 hash of the latest verified settings in the StorageMirror
   */

  uint256 internal constant _LATEST_VERIFIED_SETTINGS_SLOT = 0;

  /**
   * @notice The interface of the StorageMirrorRootRegistry contract
   */

  IStorageMirrorRootRegistry public immutable STORAGE_MIRROR_ROOT_REGISTRY;

  /**
   * @notice The interface of the block header oracle contract
   */

  IBlockHeaderOracle public immutable BLOCK_HEADER_ORACLE;

  /**
   * @notice The address of the StorageMirror contract on the home chain
   */

  address public immutable STORAGE_MIRROR;

  /**
   * @notice The mapping of the safe to the keccak256 hash of the latest verified settings
   */

  mapping(address => bytes32) public latestVerifiedSettings;

  /**
   * @notice The mapping of the safe to the timestamp of when the settings where verified
   */

  mapping(address => uint256) public latestVerifiedSettingsTimestamp;

  constructor(address _storageMirrorRootRegistry, address _storageMirror, address _blockHeaderOracle) payable {
    STORAGE_MIRROR_ROOT_REGISTRY = IStorageMirrorRootRegistry(_storageMirrorRootRegistry);
    STORAGE_MIRROR = _storageMirror;
    BLOCK_HEADER_ORACLE = IBlockHeaderOracle(_blockHeaderOracle);
  }

  function extractStorageRootAndVerifyUpdate(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorAccountProof,
    bytes memory _storageMirrorStorageProof,
    SafeTxnParams calldata _arbitraryTxnParams
  ) external {
    bytes32 _storageRoot = _extractStorageMirrorStorageRoot(_storageMirrorAccountProof);

    bytes32 _hashedProposedSettings = _verifyNewSettings(_safe, _proposedSettings, _storageMirrorStorageProof);

    // If we dont revert from the _verifyNewSettings() call, then we can update the safe

    _updateLatestVerifiedSettings(_safe, _proposedSettings);

    // Call the arbitrary transaction
    ISafe(_safe).execTransaction(
      _arbitraryTxnParams.to,
      _arbitraryTxnParams.value,
      _arbitraryTxnParams.data,
      _arbitraryTxnParams.operation,
      _arbitraryTxnParams.safeTxGas,
      _arbitraryTxnParams.baseGas,
      _arbitraryTxnParams.gasPrice,
      _arbitraryTxnParams.gasToken,
      _arbitraryTxnParams.refundReceiver,
      _arbitraryTxnParams.signatures
    );

    // Pay incentives
  }

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
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorStorageProof,
    SafeTxnParams calldata _arbitraryTxnParams
  ) external {
    bytes32 _hashedProposedSettings = _verifyNewSettings(_safe, _proposedSettings, _storageMirrorStorageProof);

    // If we dont revert from the _verifyNewSettings() call, then we can update the safe

    _updateLatestVerifiedSettings(_safe, _proposedSettings);

    // Call the arbitrary transaction
    ISafe(_safe).execTransaction(
      _arbitraryTxnParams.to,
      _arbitraryTxnParams.value,
      _arbitraryTxnParams.data,
      _arbitraryTxnParams.operation,
      _arbitraryTxnParams.safeTxGas,
      _arbitraryTxnParams.baseGas,
      _arbitraryTxnParams.gasPrice,
      _arbitraryTxnParams.gasToken,
      _arbitraryTxnParams.refundReceiver,
      _arbitraryTxnParams.signatures
    );

    // Pay incentives
    // TODO: Calculations for incentives so its not hardcoded to 1e18
    ISafe(_safe).execTransactionFromModule(msg.sender, 1e18, '', Enum.Operation.Call);

    // Make the storage updates at the end of the call to save gas in a revert scenario
    latestVerifiedSettings[_safe] = _hashedProposedSettings;
    latestVerifiedSettingsTimestamp[_safe] = block.timestamp;

    emit VerifiedUpdate(_safe, _hashedProposedSettings);
  }

  /**
   * @notice The function extracts the storage root of the StorageMirror contract from a given account proof
   *
   * @param _storageMirrorAccountProof The account proof of the StorageMirror contract from the latest block
   */

  function extractStorageMirrorStorageRoot(bytes memory _storageMirrorAccountProof)
    external
    view
    returns (bytes32 _storageRoot)
  {
    _storageRoot = _extractStorageMirrorStorageRoot(_storageMirrorAccountProof);
  }

  /**
   * @notice The function extracts the storage root of the StorageMirror contract from a given account proof
   *
   * @param _storageMirrorAccountProof The account proof of the StorageMirror contract from the latest block
   */

  function _extractStorageMirrorStorageRoot(bytes memory _storageMirrorAccountProof)
    internal
    view
    returns (bytes32 _storageRoot)
  {
    (bytes memory _blockHeader,) = BLOCK_HEADER_ORACLE.getLatestBlockHeader();

    StateVerifier.BlockHeader memory _parsedBlockHeader = StateVerifier.verifyBlockHeader(_blockHeader);

    bytes memory _rlpAccount = MerklePatriciaProofVerifier.extractProofValue(
      _parsedBlockHeader.stateRootHash,
      abi.encodePacked(keccak256(abi.encode(STORAGE_MIRROR))),
      _storageMirrorAccountProof.toRlpItem().toList()
    );

    _storageRoot = StateVerifier.extractStorageRootFromAccount(_rlpAccount);
  }

  /**
   * @notice The function that verifies a given storage proof for the proposed settings
   *
   * @param _safe The address of the safe that has new settings
   * @param _proposedSettings The new settings that are being proposed
   * @param _storageMirrorStorageProof The storage proof of the StorageMirror contract on the home chain
   * @return _hashedProposedSettings The keccak256 hash of the proposed settings
   */

  function _verifyNewSettings(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof
  ) internal view virtual returns (bytes32 _hashedProposedSettings) {
    bytes32 _latestStorageRoot = STORAGE_MIRROR_ROOT_REGISTRY.latestVerifiedStorageRoot();

    // The slot of where the latest settings hash is stored in the storage mirror
    bytes32 _safeSettingsSlot = keccak256(abi.encode(_safe, _LATEST_VERIFIED_SETTINGS_SLOT));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    RLPReader.RLPItem[] memory _stack = _storageMirrorStorageProof.toRlpItem().toList();

    bytes memory _slotValue =
      MerklePatriciaProofVerifier.extractProofValue(_latestStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _stack);

    bytes32 _hashedSavedSettings = _bytesToBytes32(_slotValue);

    _hashedProposedSettings = keccak256(abi.encode(_proposedSettings));

    if (_hashedProposedSettings != _hashedSavedSettings) revert SettingsDontMatch();
  }

  /**
   * @notice The function that updates the safe with the latest verified settings
   *
   * @param _safe The address of the safe that has new settings
   * @param _proposedSettings The new settings that are being updated to
   */

  function _updateLatestVerifiedSettings(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings
  ) internal {
    address[] memory _oldOwners = ISafe(_safe).getOwners();
    uint256 _newThreshold = _proposedSettings.threshold;
    address[] memory _newOwners = _proposedSettings.owners;
    bool _hasUpdatedThreshold;

    // NOTE: Threshold is automatically updated inside these calls if it needs to be updated
    for (uint256 _i; _i < _newOwners.length;) {
      if (!ISafe(_safe).isOwner(_newOwners[_i])) {
        _hasUpdatedThreshold = true;
        ISafe(_safe).execTransactionFromModule(
          _safe,
          0,
          abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, _newOwners[_i], _newThreshold),
          Enum.Operation.Call
        );
      }

      unchecked {
        ++_i;
      }
    }

    for (uint256 _i; _i < _oldOwners.length;) {
      if (!_linearSearchOwners(_oldOwners[_i], _newOwners)) {
        _hasUpdatedThreshold = true;
        ISafe(_safe).execTransactionFromModule(
          _safe,
          0,
          abi.encodeWithSelector(
            ISafe.removeOwner.selector,
            _oldOwners[_i],
            int256(_i) - 1 < 0 ? _SENTINEL_OWNERS : _oldOwners[_i - 1],
            _newThreshold
          ),
          Enum.Operation.Call
        );
      }

      unchecked {
        ++_i;
      }
    }

    // If the threshold has not been updated, then we need to check if it needs to be updated
    if (!_hasUpdatedThreshold) {
      uint256 _oldThreshold = ISafe(_safe).getThreshold();

      if (_oldThreshold != _newThreshold) {
        ISafe(_safe).execTransactionFromModule(
          _safe, 0, abi.encodeWithSelector(ISafe.changeThreshold.selector, _newThreshold), Enum.Operation.Call
        );
      }
    }
  }

  /**
   * @notice The function that linearly searches an array of addresses for a given address
   *
   * @param _owner The address to search for
   * @param _owners The array of addresses to search through
   * @return _result If the address was found or not
   */

  function _linearSearchOwners(address _owner, address[] memory _owners) internal pure returns (bool _result) {
    for (uint256 _i; _i < _owners.length;) {
      if (_owners[_i] == _owner) {
        _result = true;
        break;
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @notice Helpers function to convert bytes to bytes32
   *
   * @param _source The bytes to convert
   * @return _result The bytes32 variable
   */

  function _bytesToBytes32(bytes memory _source) internal pure returns (bytes32 _result) {
    // Ensure the source data is 32 bytes or less

    // Sanity check the keccak256() of  the security settings should always fit in 32 bytes
    if (_source.length > 32) revert BytesToBytes32Failed();

    // Copy the data into the bytes32 variable
    assembly {
      _result := mload(add(_source, 32))
    }
  }
}
