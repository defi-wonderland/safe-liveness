// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';

contract CommonE2EBase is DSTestFull {
  uint256 internal constant _FORK_BLOCK = 15_452_788;

  address internal _user = _label('user');
  address internal _owner = _label('owner');

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
  }
}
