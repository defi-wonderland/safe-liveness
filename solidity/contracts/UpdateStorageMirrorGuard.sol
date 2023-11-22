// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {BaseGuard} from 'safe-contracts/base/GuardManager.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {ISafe} from 'interfaces/ISafe.sol';

/**
 * @title UpdateStorageMirrorGuard
 * @notice This guard is responsible for calling the GuardCallbackModule when a change in the settings of a safe is executed.
 */
contract UpdateStorageMirrorGuard is BaseGuard {
  /**
   * @notice Emits when a change in a safe's settings is observed
   */
  event SettingsChanged(address indexed _safe, bytes32 indexed _settingsHash, IStorageMirror.SafeSettings _settings);
  /**
   * @notice The address of the guard callback module
   */

  IGuardCallbackModule public immutable GUARD_CALLBACK_MODULE;

  constructor(IGuardCallbackModule _guardCallbackModule) {
    GUARD_CALLBACK_MODULE = _guardCallbackModule;
  }

  /**
   * @notice Guard hook that is called before a Safe transaction is executed
   */
  // solhint-disable no-unused-vars
  function checkTransaction(
    address _to,
    uint256 _value,
    bytes memory _data,
    Enum.Operation _operation,
    uint256 _safeTxGas,
    uint256 _baseGas,
    uint256 _gasPrice,
    address _gasToken,
    address payable _refundReceiver,
    bytes memory _signatures,
    address _msgSender
  ) external {
    // TODO: This can be improved with the decoding of the data to accurate catch a change of the safe's settings
  }

  /**
   * @notice Guard hook that is called after a Safe transaction is executed
   * @dev It should call the GuardCallbackModule
   * @dev The msg.sender should be the safe
   */
  function checkAfterExecution(bytes32 _txHash, bool _success) external {
    if (_success) {
      address[] memory _owners = ISafe(msg.sender).getOwners();
      uint256 _threshold = ISafe(msg.sender).getThreshold();

      IStorageMirror.SafeSettings memory _safeSettings =
        IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold});
      bytes32 _settingsHash = keccak256(abi.encode(_safeSettings));

      // NOTE: No need to reset settings as this function will only be called when the settings change
      GUARD_CALLBACK_MODULE.saveUpdatedSettings(msg.sender, _settingsHash);

      emit SettingsChanged(msg.sender, _settingsHash, _safeSettings);
    }
  }
}
