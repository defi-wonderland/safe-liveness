// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';

contract CommonE2EBase is DSTestPlus {
  uint256 internal constant _FORK_BLOCK = 15_452_788;

  address internal _user = makeAddr('user');
  address internal _owner = makeAddr('owner');

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
  }
}
