// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IStorageMirror {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emits when the settings have been updated
   *
   * @param _safe The address of the safe
   * @param _settingsHash The hash of the settings
   * @param _safeSettings The plaintext of the settings
   */
  event SettingsUpdated(address indexed _safe, bytes32 indexed _settingsHash, SafeSettings _safeSettings);

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  struct SafeSettings {
    // Array of the safes owners
    address[] owners;
    // The threshold of the safe
    uint256 threshold;
  }

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The mapping of the safe to the keccak256(abi.encode(SafeSettings))
   */
  function latestSettingsHash(address _safe) external view returns (bytes32 _latestSettingsHash);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Updates a safe's settings hash
   * @dev The safe should always be msg.sender
   * @param _safeSettings The settings we are going to update to
   */
  function update(SafeSettings memory _safeSettings) external;
}
