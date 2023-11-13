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
}
