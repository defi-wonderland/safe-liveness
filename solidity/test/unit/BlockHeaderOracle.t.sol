// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {BlockHeaderOracle} from 'contracts/BlockHeaderOracle.sol';

abstract contract Base is Test {
  event BlockHeaderUpdated(bytes _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber);

  BlockHeaderOracle public oracle;

  function setUp() public {
    oracle = new BlockHeaderOracle();
  }
}

contract UnitBlockHeaderOracle is Base {
  function testUpdateBlockHeader(bytes memory _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber) public {
    vm.expectEmit(true, true, true, true);
    emit BlockHeaderUpdated(_blockHeader, _blockTimestamp, _blockNumber);
    oracle.updateBlockHeader(_blockHeader, _blockTimestamp, _blockNumber);

    assertEq(_blockHeader, oracle.blockHeader(), 'Block header should be saved');
    assertEq(_blockTimestamp, oracle.blockTimestamp(), 'Block timestamp should be saved');
  }

  function testGetLatestBlockHeader() public {
    bytes memory _blockHeader = '0x1234';
    uint256 _blockTimestamp = 1234;
    uint256 _blockNumber = 1234;

    oracle.updateBlockHeader(_blockHeader, _blockTimestamp, _blockNumber);

    (bytes memory _savedBlockHeader, uint256 _savedBlockTimestamp) = oracle.getLatestBlockHeader();

    assertEq(_blockHeader, _savedBlockHeader, 'Block header should be saved');
    assertEq(_blockTimestamp, _savedBlockTimestamp, 'Block timestamp should be saved');
  }
}
