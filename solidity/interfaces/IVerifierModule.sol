// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IVerifierModule {
  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The timestamp when the latest settings were verified
   * @param _safe The address of the safe
   * @return _timestamp The timestamp
   */
  function latestVerifiedSettingsTimestamp(address _safe) external view returns (uint256 _timestamp);
}
