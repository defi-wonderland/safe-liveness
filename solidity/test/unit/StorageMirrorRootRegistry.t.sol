// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {BlockHeaderOracle} from 'contracts/BlockHeaderOracle.sol';
import {StorageMirrorRootRegistry} from 'contracts/StorageMirrorRootRegistry.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

contract StorageMirrorRootRegistryForTest is StorageMirrorRootRegistry {
  constructor(
    address _storageMirror,
    IVerifierModule _verifierModule,
    IBlockHeaderOracle _blockHeaderOracle
  ) StorageMirrorRootRegistry(_storageMirror, _verifierModule, _blockHeaderOracle) {}

  function queryL1BlockHeader() external view returns (bytes memory _blockHeader) {
    _blockHeader = _queryL1BlockHeader();
  }
}

abstract contract Base is Test {
  event VerifiedStorageMirrorStorageRoot(uint256 indexed _homeChainBlockNumber, bytes32 _storageRoot);

  address public user;
  address public storageMirror;
  StorageMirrorRootRegistry public storageMirrorRootRegistry;
  StorageMirrorRootRegistryForTest public storageMirrorRootRegistryForTest;
  BlockHeaderOracle public blockHeaderOracle;
  IVerifierModule public verifierModule;

  function setUp() public {
    user = makeAddr('user');
    storageMirror = makeAddr('StorageMirror');
    blockHeaderOracle = new BlockHeaderOracle();
    verifierModule = IVerifierModule(makeAddr('VerifierModule'));
    storageMirrorRootRegistry =
      new StorageMirrorRootRegistry(storageMirror, verifierModule, IBlockHeaderOracle(blockHeaderOracle));
    storageMirrorRootRegistryForTest =
      new StorageMirrorRootRegistryForTest(storageMirror, verifierModule, IBlockHeaderOracle(blockHeaderOracle));
  }
}

contract UnitStorageMirrorRootRegistryQueryL1BlockHeader is Base {
  function testQueryL1BlockHeader(bytes memory _blockHeader, uint256 _blockTimestamp, uint256 _blockNumber) public {
    vm.prank(user);
    blockHeaderOracle.updateBlockHeader(_blockHeader, _blockTimestamp, _blockNumber);

    vm.expectCall(address(blockHeaderOracle), abi.encodeWithSelector(blockHeaderOracle.getLatestBlockHeader.selector));
    vm.prank(user);
    bytes memory _savedBlockHeader = storageMirrorRootRegistryForTest.queryL1BlockHeader();

    assertEq(_blockHeader, _savedBlockHeader, 'Block header should be saved');
  }
}

contract UnitStorageMirrorRootRegistryProposeAndVerifyStorageMirrorStorageRoot is Base {
  function testProposeAndVerifyStorageMirrorStorageRoot(bytes memory _accountProof) public {
    bytes memory _blockHeader = '0x1234';
    uint256 _blockTimestamp = 1234;
    uint256 _blockNumber = 1234;
    bytes32 _storageRoot = '0x1234';

    vm.prank(user);
    blockHeaderOracle.updateBlockHeader(_blockHeader, _blockTimestamp, _blockNumber);

    vm.mockCall(
      address(verifierModule),
      abi.encodeWithSelector(verifierModule.extractStorageMirrorStorageRoot.selector, _blockHeader, _accountProof),
      abi.encode(_storageRoot, _blockNumber)
    );
    vm.expectCall(
      address(verifierModule),
      abi.encodeWithSelector(verifierModule.extractStorageMirrorStorageRoot.selector, _blockHeader, _accountProof)
    );

    vm.expectEmit(true, true, true, true);
    emit VerifiedStorageMirrorStorageRoot(_blockNumber, _storageRoot);

    vm.prank(user);
    storageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot(_accountProof);

    assertEq(
      _storageRoot, storageMirrorRootRegistry.latestVerifiedStorageMirrorStorageRoot(), 'Storage root should be saved'
    );
  }
}
