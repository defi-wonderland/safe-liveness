// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';

/**
 * @title BlockHeaderOracle
 * @notice This contract's purpose is to return the latest stored L1 block header and timestamp
 * @notice Every X minutes a "magical" off-chain agent provides the latest block header and timestamp
 */
contract BlockHeaderOracle is IBlockHeaderOracle {
  /**
   * @notice The block header
   */
  bytes public blockHeader;

  /**
   * @notice The block timestamp of the latest block header
   */
  uint256 public blockTimestamp;

  /**
   * @notice Updates the block header and timestamp
   * @param _blockHeader The block header
   * @param _blockTimestamp The block timestamp
   * @param _blockNumber The block number
   */
  function updateBlockHeader(bytes memory _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber) external {
    blockHeader = _blockHeader;
    blockTimestamp = _blockTimestamp;

    emit BlockHeaderUpdated(_blockHeader, _blockTimestamp, _blockNumber);
  }

  /**
   * @notice Returns the latest block header and timestamp
   * @return _blockHeader The block header
   * @return _blockTimestamp The block timestamp
   */
  function getLatestBlockHeader() external view returns (bytes memory _blockHeader, uint256 _blockTimestamp) {
    return (blockHeader, blockTimestamp);
  }
}
