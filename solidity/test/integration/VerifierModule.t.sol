// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Enum} from 'safe-contracts/common/Enum.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';

contract IntegrationVerifierModule is IntegrationBase {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  IVerifierModule.SafeTxnParams public txn = IVerifierModule.SafeTxnParams({
    to: address(0),
    value: 1,
    data: '',
    operation: Enum.Operation.Call,
    safeTxGas: 0,
    baseGas: 0,
    gasPrice: 0,
    gasToken: address(0),
    refundReceiver: payable(address(0)),
    signatures: ''
  });

  function setUp() public override {
    super.setUp();

    vm.selectFork(_mainnetForkId);

    vm.prank(address(_deployer));
    address(nonHomeChainSafe).call{value: 1e18}('');
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

  function testProposeAndVerify() public {
    // Add an owner so the settings dont match the home chain
    vm.prank(address(nonHomeChainSafe));
    nonHomeChainSafe.addOwnerWithThreshold(address(_searcher), 1);

    address[] memory _fakeOwners = nonHomeChainSafe.getOwners();

    assertEq(_fakeOwners.length, 2, 'Owners should be 2');

    bytes memory _encodedTxn = nonHomeChainSafe.encodeTransactionData(
      address(0), 1, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonHomeChainSafe.nonce()
    );

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(vm.envUint('MAINNET_DEPLOYER_PK'), keccak256(_encodedTxn));
    txn.signatures = abi.encodePacked(_r, _s, _v);

    IStorageMirror.SafeSettings memory _safeSettings = IStorageMirror.SafeSettings({owners: _owners, threshold: 1});

    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    StateVerifier.BlockHeader memory _blockHeaderStruct = StateVerifier.verifyBlockHeader(_blockHeader);

    oracle.updateBlockHeader(_blockHeader, _blockHeaderStruct.timestamp, _blockHeaderStruct.number);

    storageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot(_accountProof);

    uint256 _searcherBalance = address(_searcher).balance;
    uint256 _addressZeroBalance = address(0).balance;

    vm.prank(_searcher);
    verifierModule.proposeAndVerifyUpdate(address(nonHomeChainSafe), _safeSettings, _storageProof, txn);

    address[] memory _newOwners = nonHomeChainSafe.getOwners();

    assertEq(_newOwners.length, 1, 'Owners should be 1');
    assertEq(_newOwners[0], address(_deployer), 'Owner should be the deployer');
    assertGt(address(_searcher).balance, _searcherBalance, 'Searcher should be rewarded');
    assertGt(
      address(0).balance,
      _addressZeroBalance,
      'Address zero should have more funds because we sent 1 wei the arbitrary txn'
    );
  }

  function testChangingOwnersAndThreshold() public {
    // Add an owner so the settings dont match the home chain
    vm.startPrank(address(nonHomeChainSafe));
    nonHomeChainSafe.addOwnerWithThreshold(address(_searcher), 1);
    nonHomeChainSafe.changeThreshold(2);
    vm.stopPrank();

    address[] memory _fakeOwners = nonHomeChainSafe.getOwners();

    assertEq(_fakeOwners.length, 2, 'Owners should be 2');
    assertEq(nonHomeChainSafe.getThreshold(), 2, 'Threshold should be 2');

    bytes memory _encodedTxn = nonHomeChainSafe.encodeTransactionData(
      address(0), 1, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonHomeChainSafe.nonce()
    );

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(vm.envUint('MAINNET_DEPLOYER_PK'), keccak256(_encodedTxn));
    txn.signatures = abi.encodePacked(_r, _s, _v);

    IStorageMirror.SafeSettings memory _safeSettings = IStorageMirror.SafeSettings({owners: _owners, threshold: 1});

    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    StateVerifier.BlockHeader memory _blockHeaderStruct = StateVerifier.verifyBlockHeader(_blockHeader);

    oracle.updateBlockHeader(_blockHeader, _blockHeaderStruct.timestamp, _blockHeaderStruct.number);

    storageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot(_accountProof);

    uint256 _searcherBalance = address(_searcher).balance;
    uint256 _addressZeroBalance = address(0).balance;

    vm.prank(_searcher);
    verifierModule.proposeAndVerifyUpdate(address(nonHomeChainSafe), _safeSettings, _storageProof, txn);

    address[] memory _newOwners = nonHomeChainSafe.getOwners();

    assertEq(_newOwners.length, 1, 'Owners should be 1');
    assertEq(_newOwners[0], address(_deployer), 'Owner should be the deployer');
    assertGt(address(_searcher).balance, _searcherBalance, 'Searcher should be rewarded');
    assertGt(
      address(0).balance,
      _addressZeroBalance,
      'Address zero should have more funds because we sent 1 wei the arbitrary txn'
    );
  }

  function testVerifySwappingOwners() public {
    // Add an owner so the settings dont match the home chain
    vm.startPrank(address(nonHomeChainSafe));
    nonHomeChainSafe.addOwnerWithThreshold(address(_searcher), 1);
    nonHomeChainSafe.removeOwner(address(_searcher), address(_deployer), 1);
    vm.stopPrank();

    address[] memory _fakeOwners = nonHomeChainSafe.getOwners();

    assertEq(_fakeOwners.length, 1, 'Owners should be 1');

    bytes memory _encodedTxn = nonHomeChainSafe.encodeTransactionData(
      address(0), 1, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonHomeChainSafe.nonce()
    );

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(vm.envUint('MAINNET_DEPLOYER_PK'), keccak256(_encodedTxn));
    txn.signatures = abi.encodePacked(_r, _s, _v);

    IStorageMirror.SafeSettings memory _safeSettings = IStorageMirror.SafeSettings({owners: _owners, threshold: 1});

    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    StateVerifier.BlockHeader memory _blockHeaderStruct = StateVerifier.verifyBlockHeader(_blockHeader);

    oracle.updateBlockHeader(_blockHeader, _blockHeaderStruct.timestamp, _blockHeaderStruct.number);

    storageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot(_accountProof);

    uint256 _searcherBalance = address(_searcher).balance;
    uint256 _addressZeroBalance = address(0).balance;

    vm.prank(_searcher);
    verifierModule.proposeAndVerifyUpdate(address(nonHomeChainSafe), _safeSettings, _storageProof, txn);

    address[] memory _newOwners = nonHomeChainSafe.getOwners();

    assertEq(_newOwners.length, 1, 'Owners should be 1');
    assertEq(_newOwners[0], address(_deployer), 'Owner should be the deployer');
    assertGt(address(_searcher).balance, _searcherBalance, 'Searcher should be rewarded');
    assertGt(
      address(0).balance,
      _addressZeroBalance,
      'Address zero should have more funds because we sent 1 wei the arbitrary txn'
    );
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

  function testFullFlowOfUpdatingSafe() public {
    // Add an owner so the settings dont match the home chain
    vm.prank(address(nonHomeChainSafe));
    nonHomeChainSafe.addOwnerWithThreshold(address(_searcher), 1);

    address[] memory _fakeOwners = nonHomeChainSafe.getOwners();

    assertEq(_fakeOwners.length, 2, 'Owners should be 2');

    bytes memory _encodedTxn = nonHomeChainSafe.encodeTransactionData(
      address(0), 1, '', Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonHomeChainSafe.nonce()
    );

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(vm.envUint('MAINNET_DEPLOYER_PK'), keccak256(_encodedTxn));
    txn.signatures = abi.encodePacked(_r, _s, _v);

    IStorageMirror.SafeSettings memory _safeSettings = IStorageMirror.SafeSettings({owners: _owners, threshold: 1});

    (bytes memory _storageProof, bytes memory _accountProof, bytes memory _blockHeader) = getProof();

    StateVerifier.BlockHeader memory _blockHeaderStruct = StateVerifier.verifyBlockHeader(_blockHeader);

    oracle.updateBlockHeader(_blockHeader, _blockHeaderStruct.timestamp, _blockHeaderStruct.number);

    assertEq(oracle.blockHeader(), _blockHeader, 'Block header should be saved');
    assertEq(oracle.blockTimestamp(), _blockHeaderStruct.timestamp, 'Timestamp should be saved');

    uint256 _searcherBalance = address(_searcher).balance;
    uint256 _addressZeroBalance = address(0).balance;

    vm.prank(_searcher);
    verifierModule.extractStorageRootAndVerifyUpdate(
      address(nonHomeChainSafe), _safeSettings, _accountProof, _storageProof, txn
    );

    address[] memory _newOwners = nonHomeChainSafe.getOwners();

    assertEq(_newOwners.length, 1, 'Owners should be 1');
    assertEq(_newOwners[0], address(_deployer), 'Owner should be the deployer');
    assertGt(address(_searcher).balance, _searcherBalance, 'Searcher should be rewarded');
    assertGt(
      address(0).balance,
      _addressZeroBalance,
      'Address zero should have more funds because we sent 1 wei the arbitrary txn'
    );
  }
}
