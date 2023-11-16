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
  ) external returns (bool _success);

  /**
   * @notice Executes a `operation` {0: Call, 1: DelegateCall}} transaction to `to` with `value` (Native Currency)
   *          and pays `gasPrice` * `gasLimit` in `gasToken` token to `refundReceiver`.
   * @dev The fees are always transferred, even if the user transaction fails.
   *      This method doesn't perform any sanity check of the transaction, such as:
   *      - if the contract at `to` address has code or not
   *      - if the `gasToken` is a contract or not
   *      It is the responsibility of the caller to perform such checks.
   * @param to Destination address of Safe transaction.
   * @param value Ether value of Safe transaction.
   * @param data Data payload of Safe transaction.
   * @param operation Operation type of Safe transaction.
   * @param safeTxGas Gas that should be used for the Safe transaction.
   * @param baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
   * @param gasPrice Gas price that should be used for the payment calculation.
   * @param gasToken Token address (or 0 if ETH) that is used for the payment.
   * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
   * @param signatures Signature data that should be verified.
   *                   Can be packed ECDSA signature ({bytes32 r}{bytes32 s}{uint8 v}), contract signature (EIP-1271) or approved hash.
   * @return success Boolean indicating transaction's success.
   */
  function execTransaction(
    address to,
    uint256 value,
    bytes calldata data,
    Enum.Operation operation,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver,
    bytes memory signatures
  ) external payable returns (bool success);

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

  /**
   * @notice Returns the number of required confirmations for a Safe transaction aka the threshold.
   * @return Threshold number.
   */
  function getThreshold() external view returns (uint256);

  /**
   * @notice Changes the threshold of the Safe to `_threshold`.
   * @dev This can only be done via a Safe transaction.
   * @param _threshold New threshold.
   */
  function changeThreshold(uint256 _threshold) external;

  /**
   * @notice Returns a list of Safe owners.
   * @return Array of Safe owners.
   */
  function getOwners() external view returns (address[] memory);

  /**
   * @notice Adds the owner `owner` to the Safe and updates the threshold to `_threshold`.
   * @dev This can only be done via a Safe transaction.
   * @param owner New owner address.
   * @param _threshold New threshold.
   */
  function addOwnerWithThreshold(address owner, uint256 _threshold) external;

  /**
   * @notice Returns the nonce of the safe
   */
  function nonce() external view returns (uint256);

  /**
   * @notice Sets an initial storage of the Safe contract.
   * @dev This method can only be called once.
   *      If a proxy was created without setting up, anyone can call setup and claim the proxy.
   * @param _owners List of Safe owners.
   * @param _threshold Number of required confirmations for a Safe transaction.
   * @param to Contract address for optional delegate call.
   * @param data Data payload for optional delegate call.
   * @param fallbackHandler Handler for fallback calls to this contract
   * @param paymentToken Token that should be used for the payment (0 is ETH)
   * @param payment Value that should be paid
   * @param paymentReceiver Address that should receive the payment (or 0 if tx.origin)
   */
  function setup(
    address[] calldata _owners,
    uint256 _threshold,
    address to,
    bytes calldata data,
    address fallbackHandler,
    address paymentToken,
    uint256 payment,
    address payable paymentReceiver
  ) external;

  /**
   * @notice Returns the pre-image of the transaction hash (see getTransactionHash).
   * @param to Destination address.
   * @param value Ether value.
   * @param data Data payload.
   * @param operation Operation type.
   * @param safeTxGas Gas that should be used for the safe transaction.
   * @param baseGas Gas costs for that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
   * @param gasPrice Maximum gas price that should be used for this transaction.
   * @param gasToken Token address (or 0 if ETH) that is used for the payment.
   * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
   * @param _nonce Transaction nonce.
   * @return Transaction hash bytes.
   */
  function encodeTransactionData(
    address to,
    uint256 value,
    bytes calldata data,
    Enum.Operation operation,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address refundReceiver,
    uint256 _nonce
  ) external view returns (bytes memory);
}
