// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IGuardCallbackModule {
  function saveUpdatedSettings(address _safe, bytes32 _settingsHash) external;
}
