// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';

/**
 * @title GuardCallbackModule
 * @notice This contract is a module that is used to save the updated settings to the StorageMirror.
 * @dev It can also be used to set the guard and module in one transaction.
 */
contract GuardCallbackModule is IGuardCallbackModule {
  address internal constant _SENTINEL_MODULES = address(0x1);
  uint256 internal constant _GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

  // @dev This address is used to check address(this) in a delegate call
  address internal immutable _THIS_ADDRESS;
  address public immutable STORAGE_MIRROR;
  address public immutable GUARD;

  constructor(address _storageMirror, address _guard) {
    _THIS_ADDRESS = address(this);
    STORAGE_MIRROR = _storageMirror;
    GUARD = _guard;
  }

  /**
   * @notice Sets up the guard and module for the safe in one transaction.
   * @dev This function can only be called with a delegatecall from a safe.
   */

  function setupGuardAndModule() external {
    // This function can only be called with a delegatecall()
    if (_THIS_ADDRESS == address(this)) revert OnlyDelegateCall();

    address _thisAddress = _THIS_ADDRESS;
    address _guard = GUARD;
    bytes32 _moduleMappingLocation = keccak256(abi.encode(1, _THIS_ADDRESS));
    bytes32 _sentinelMappingLocation = keccak256(abi.encode(1, _SENTINEL_MODULES));

    assembly {
      // Save guard
      sstore(_GUARD_STORAGE_SLOT, _guard)

      // Save mappings
      sstore(_moduleMappingLocation, sload(_sentinelMappingLocation))
      sstore(_sentinelMappingLocation, _thisAddress)
    }

    emit ChangedGuard(_guard);
    emit EnabledModule(_thisAddress);
  }

  /**
   * @notice Saves the updated settings for the safe to the StorageMirror.
   * @dev Executes a transaction from the module to update the safe settings in the StorageMirror.
   * @param _safe The address of the safe.
   * @param _safeSettings The new settings for the safe.
   */

  function saveUpdatedSettings(address _safe, IStorageMirror.SafeSettings memory _safeSettings) external {
    if (msg.sender != GUARD) revert OnlyGuard();
    bytes memory _txData = abi.encodeWithSelector(IStorageMirror.update.selector, _safeSettings);
    ISafe(_safe).execTransactionFromModule(STORAGE_MIRROR, 0, _txData, Enum.Operation.Call);
  }
}
