// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {BaseGuard} from 'safe-contracts/base/GuardManager.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

/**
 * @title NeedsUpdateGuard
 * @notice This guard should prevent the safe from executing any transaction if an update is needed.
 * @notice An update is needed based on the safe owner's time inputed on how long an update is trusted.
 */
contract NeedsUpdateGuard is BaseGuard {
  /**
   * @notice Emits when the owner changes the trustLatestUpdateForSeconds
   * @param _safe The address of the safe
   * @param _trustLatestUpdateForSeconds The new trustLatestUpdateForSeconds, how many seconds the safe trusts the last update
   */
  event TrustLatestUpdateForSecondsChanged(address indexed _safe, uint256 _trustLatestUpdateForSeconds);

  /**
   * @notice Throws if the safe needs an update
   */
  error NeedsUpdateGuard_NeedsUpdate();

  /**
   * @notice The verifier module
   */
  IVerifierModule public immutable VERIFIER_MODULE;

  /**
   * @notice How many seconds the safe trusts the last update
   */
  mapping(address => uint256) public trustLatestUpdateForSeconds;

  constructor(IVerifierModule _verifierModule) {
    VERIFIER_MODULE = _verifierModule;
  }

  /**
   * @notice Guard hook that is called before a Safe transaction is executed
   * @dev This function should revert if the safe needs an update
   * @dev WARNING: This can brick the safe if the owner doesn't update the settings or change the trustLatestUpdateForSeconds
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
    uint256 _trustLatestUpdateForSeconds = trustLatestUpdateForSeconds[msg.sender];

    if (_lastVerifiedUpdateTimestamp + _trustLatestUpdateForSeconds < block.timestamp) {
      revert NeedsUpdateGuard_NeedsUpdate();
    }
  }

  /**
   * @notice Guard hook that is called after a Safe transaction is executed
   */
  function checkAfterExecution(bytes32 _txHash, bool _success) external {}

  /**
   * @notice Should update the safe's trustLatestUpdateForSeconds
   * @dev This function should be called by the safe
   * @param _trustLatestUpdateForSeconds The new trustLatestUpdateForSeconds, how many seconds the safe trusts the last verified update
   */
  function updateTrustLatestUpdateForSeconds(uint256 _trustLatestUpdateForSeconds) external {
    trustLatestUpdateForSeconds[msg.sender] = _trustLatestUpdateForSeconds;
    emit TrustLatestUpdateForSecondsChanged(msg.sender, _trustLatestUpdateForSeconds);
  }
}
