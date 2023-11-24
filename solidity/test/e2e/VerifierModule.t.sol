// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from 'test/e2e/Common.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';

contract VerifierModuleE2E is CommonE2EBase {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  function setUp() public override {
    super.setUp();

    vm.selectFork(_optimismForkId);
  }

  function testExtractStateRoot() public {
    (, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    (bytes32 _stateRoot, uint256 _blockNumber) =
      verifierModule.extractStorageMirrorStorageRoot(_accountProof, _blockHeader);

    uint256 _expectedBlockNumber = vm.parseJsonUint(vm.readFile('./proofs/proof.json'), '$.blockNumber');

    assertEq(address(storageMirror), verifierModule.STORAGE_MIRROR());
    assertTrue(_stateRoot != bytes32(0));
    assertEq(_blockNumber, _expectedBlockNumber);
  }

  function testStorageProofIsValid() public {
    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    (bytes32 _stateRoot,) = verifierModule.extractStorageMirrorStorageRoot(_accountProof, _blockHeader);

    bytes32 _slot = keccak256(abi.encode(address(safe), 0));
    bytes32 _slotHash = keccak256(abi.encodePacked(_slot));

    address[] memory _owners = new address[](1);
    _owners[0] = _deployer;

    uint256 _threshold = 1;

    bytes32 _expectedSettingsHash =
      keccak256(abi.encode(IStorageMirror.SafeSettings({owners: _owners, threshold: _threshold})));

    bytes memory _calculatedSettingsHash = MerklePatriciaProofVerifier.extractProofValue(
      _stateRoot, abi.encodePacked(_slotHash), _storageProof.toRlpItem().toList()
    );

    bytes32 _calculatedSettingsHashBytes32 = _bytesToBytes32(_calculatedSettingsHash);

    assertEq(_calculatedSettingsHashBytes32, _expectedSettingsHash);
  }
}
