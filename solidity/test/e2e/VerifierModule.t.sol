// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from 'test/e2e/Common.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';

contract VerifierModuleE2E is CommonE2EBase {
  function testExtractStateRoot() public {
    (, bytes memory _accountProof, bytes memory _blockHeader) = getProof(
      vm.rpcUrl('mainnet_e2e'),
      vm.toString(address(storageMirror)),
      vm.toString((keccak256(abi.encode(address(safe), 0))))
    );
    (bytes32 _stateRoot, uint256 _blockNumber) =
      verifierModule.extractStorageMirrorStorageRoot(_accountProof, _blockHeader);

    uint256 _expectedBlockNumber = vm.parseJsonUint(vm.readFile('./proofs/proof.json'), '$.blockNumber');

    assertTrue(_stateRoot != bytes32(0));
    assertEq(_blockNumber, _expectedBlockNumber);
  }
}
