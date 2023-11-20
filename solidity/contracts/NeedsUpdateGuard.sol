// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {BaseGuard} from 'safe-contracts/base/GuardManager.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

/**
 * @title NeedsUpdateGuard
 * @notice This guard should prevent the safe from executing any transaction if an update is needed.
 * @notice An update is needed based on the safe owner's security settings.
 */
contract NeedsUpdateGuard is BaseGuard {
  /**
   * @notice Emits when the owner changes the update security settings
   * @param _safe The address of the safe
   * @param _newSecuritySettings The new security settings, how many seconds the safe trusts the last update
   */
  event SecuritySettingsChanged(address indexed _safe, uint256 _newSecuritySettings);

  /**
   * @notice Throws if the safe needs an update
   */
  error NeedsUpdateGuard_NeedsUpdate();

  /**
   * @notice The verifier module
   */
  IVerifierModule public immutable VERIFIER_MODULE;

  /**
   * @notice The mapping of a safe's address to their security settings, how many seconds the safe trusts the last update
   */
  mapping(address => uint256) public safeSecuritySettings;

  constructor(IVerifierModule _verifierModule) {
    VERIFIER_MODULE = _verifierModule;
  }

  /**
   * @notice Guard hook that is called before a Safe transaction is executed
   * @dev This function should revert if the safe needs an update
   * @dev WARNING: This can brick the safe if the owner doesn't update the settings or change the security settings
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
    uint256 _lastVerifiedUpdateTimestamp = VERIFIER_MODULE.latestVerifiedSettingsTimestamp(msg.sender);
    uint256 _securitySettings = safeSecuritySettings[msg.sender];

    if (_lastVerifiedUpdateTimestamp + _securitySettings < block.timestamp) {
      revert NeedsUpdateGuard_NeedsUpdate();
    }
  }

  /**
   * @notice Guard hook that is called after a Safe transaction is executed
   */
  function checkAfterExecution(bytes32 _txHash, bool _success) external {}

  /**
   * @notice Should update the safe's security settings
   * @dev This function should be called by the safe
   * @param _securitySettings The new security settings, how many seconds the safe trusts the last verified update
   */
  function updateSecuritySettings(uint256 _securitySettings) external {
    safeSecuritySettings[msg.sender] = _securitySettings;
    emit SecuritySettingsChanged(msg.sender, _securitySettings);
  }
}
