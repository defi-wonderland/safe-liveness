// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

/**
 * @title StorageMirror
 * @notice This contract is a storage of information about the safe’s settings. All safe’s settings changes should be mirrored in this contract and be saved.
 * @notice In the end, this contract’s storage root is gonna be used to see if a proposed update on the non-home chain is valid.
 */
contract StorageMirror is IStorageMirror {
  /**
   * @notice The mapping of the safe to the keccak256(abi.encode(SafeSettings))
   */

  mapping(address => bytes32) public latestSettingsHash;

  /**
   * @notice Updates a safe's settings hash
   * @dev The safe should always be msg.sender
   * @param _safeSettings The settings we are going to update to
   */

  function update(SafeSettings memory _safeSettings) external {
    bytes32 _settingsHash = keccak256(abi.encode(_safeSettings));
    latestSettingsHash[msg.sender] = _settingsHash;

    emit SettingsUpdated(msg.sender, _settingsHash, _safeSettings);
  }
}
