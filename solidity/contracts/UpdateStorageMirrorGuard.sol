// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Guard} from 'safe-contracts/base/GuardManager.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';

/**
 * @title UpdateStorageMirrorGuard
 * @notice This guard is responsible for calling the GuardCallbackModule when a change in settings of a safe is executed.
 */
contract UpdateStorageMirrorGuard is Guard {
  /**
   * @notice The address of the guard callback module
   */
  IGuardCallbackModule public immutable GUARD_CALLBACK_MODULE;

  /**
   * @notice A boolean that returns true if a tx is changing the safe's settings
   */
  bool public didSettingsChange;

  /**
   * @notice The hash of the new settings
   */
  bytes32 public settingsHash;

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
    didSettingsChange = true;
    settingsHash = keccak256(abi.encodePacked('settings'));
  }

  /**
   * @notice Guard hook that is called after a Safe transaction is executed
   * @dev It should call the GuardCallbackModule
   * @dev The msg.sender should be the safe
   */
  function checkAfterExecution(bytes32 _txHash, bool _success) external {
    if (didSettingsChange && _success) {
      GUARD_CALLBACK_MODULE.saveUpdatedSettings(msg.sender, settingsHash);
      didSettingsChange = false;
      settingsHash = keccak256(abi.encodePacked(''));
    }
  }
}
