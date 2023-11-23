// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from 'test/e2e/Common.sol';

contract VerifierModuleE2E is CommonE2EBase {
  function setUp() public override {
    super.setUp();
  }

  function testProposeAndVerifyUpdate() public {
    address _storageMirrorAddr =
      vm.parseJsonAddress(vm.readFile('./solidity/scripts/HomeChainDeployments.json'), '$.StorageMirror');

    string memory _blockNumberString = vm.toString(_MAINNET_FORK_BLOCK);
    string memory _rpc = vm.rpcUrl('mainnet_e2e');
    string memory _contract = vm.toString(address(_storageMirrorAddr));
    string memory _slot = vm.toString((keccak256(abi.encode(address(safe), 0))));

    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) =
      getProof(_blockNumberString, _rpc, _contract, _slot);
  }
}
