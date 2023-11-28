// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IBlockHeaderOracle {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emits when the block header and timestamp are updated
   */
  event BlockHeaderUpdated(bytes _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The block header
   * @return _blockheader The block header
   */
  function blockHeader() external view returns (bytes memory _blockheader);

  /**
   * @notice The block timestamp of the latest block header
   * @return _blockTimestamp The block timestamp
   */
  function blockTimestamp() external view returns (uint256 _blockTimestamp);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Updates the block header and timestamp
   * @param _blockHeader The block header
   * @param _blockTimestamp The block timestamp
   * @param _blockNumber The block number
   */
  function updateBlockHeader(bytes memory _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber) external;

  /**
   * @notice Returns the latest block header and timestamp
   * @return _blockHeader The block header
   * @return _blockTimestamp The block timestamp
   */
  function getLatestBlockHeader() external view returns (bytes memory _blockHeader, uint256 _blockTimestamp);
}
