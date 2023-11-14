// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Enum} from 'safe-contracts/common/Enum.sol';

interface ISafe {
  /**
   * @notice Execute `operation` (0: Call, 1: DelegateCall) to `to` with `value` (Native Token)
   * @dev Function is virtual to allow overriding for L2 singleton to emit an event for indexing.
   * @param _to Destination address of module transaction.
   * @param _value Ether value of module transaction.
   * @param _data Data payload of module transaction.
   * @param _operation Operation type of module transaction.
   * @return _success Boolean flag indicating if the call succeeded.
   */
  function execTransactionFromModule(
    address _to,
    uint256 _value,
    bytes memory _data,
    Enum.Operation _operation
  ) external virtual returns (bool _success);

  /**
   * @dev Set a guard that checks transactions before execution
   *      This can only be done via a Safe transaction.
   *      ⚠️ IMPORTANT: Since a guard has full power to block Safe transaction execution,
   *        a broken guard can cause a denial of service for the Safe. Make sure to carefully
   *        audit the guard code and design recovery mechanisms.
   * @notice Set Transaction Guard `guard` for the Safe. Make sure you trust the guard.
   * @param guard The address of the guard to be used or the 0 address to disable the guard
   */
  function setGuard(address guard) external;

  /**
   * @notice Enables the module `module` for the Safe.
   * @dev This can only be done via a Safe transaction.
   * @param module Module to be whitelisted.
   */
  function enableModule(address module) external;
}
