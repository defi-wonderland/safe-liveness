// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from 'test/e2e/Common.sol';

contract TestE2E is CommonE2EBase {
  function setUp() public override {
    super.setUp();
  }

  function test_test() public {
    assertTrue(true);
  }
}
