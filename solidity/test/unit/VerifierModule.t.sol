// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {VerifierModule, IVerifierModule} from 'contracts/VerifierModule.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {IStorageMirror} from 'interfaces/IStorageMirror.sol';
import {IBlockHeaderOracle} from 'interfaces/IBlockHeaderOracle.sol';
import {ISafe} from 'interfaces/ISafe.sol';
import {IStorageMirrorRootRegistry} from 'interfaces/IStorageMirrorRootRegistry.sol';
import {MerklePatriciaProofVerifier} from 'libraries/MerklePatriciaProofVerifier.sol';
import {StateVerifier} from 'libraries/StateVerifier.sol';

contract TestMPT {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  function extractProofValue(
    bytes32 _root,
    bytes memory _key,
    bytes memory _storageProof
  ) external pure returns (bytes memory _value) {
    // Need to create the RLP item internally due to memory collision
    RLPReader.RLPItem[] memory _stack = _storageProof.toRlpItem().toList();
    _value = MerklePatriciaProofVerifier.extractProofValue(_root, _key, _stack);
  }

  function verifyBlockHeader(bytes memory _rlpBlockHeader)
    external
    pure
    returns (StateVerifier.BlockHeader memory _parsedBlockHeader)
  {
    _parsedBlockHeader = StateVerifier.verifyBlockHeader(_rlpBlockHeader);
  }

  function extractStorageRootFromAccount(bytes memory _rlpAccount) external pure returns (bytes32 _storageRoot) {
    _storageRoot = StateVerifier.extractStorageRootFromAccount(_rlpAccount);
  }
}

contract TestVerifierModule is VerifierModule {
  TestMPT public mpt;

  constructor(
    IStorageMirrorRootRegistry _storageMirrorRootRegistry,
    address _storageMirror,
    TestMPT _testMPT
  ) VerifierModule(_storageMirrorRootRegistry, _storageMirror) {
    mpt = _testMPT;
  }

  // Matches the function but needed an external MPT caller to mock it
  function verifyNewSettings(
    address _safe,
    IStorageMirror.SafeSettings memory _proposedSettings,
    bytes memory _storageMirrorStorageProof
  ) public view returns (bytes32 _hashedProposedSettings) {
    bytes32 _latestStorageRoot = IStorageMirrorRootRegistry(STORAGE_MIRROR_ROOT_REGISTRY).latestVerifiedStorageRoot();

    // The slot of where the latest settings hash is stored in the storage mirror
    bytes32 _safeSettingsSlot = keccak256(abi.encode(_safe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _slotValue =
      mpt.extractProofValue(_latestStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageMirrorStorageProof);

    bytes32 _hashedSavedSettings = _bytesToBytes32(_slotValue);

    _hashedProposedSettings = keccak256(abi.encode(_proposedSettings));

    if (_hashedProposedSettings != _hashedSavedSettings) revert SettingsDontMatch();
  }

  function updateLatestVerifiedSettings(address _safe, IStorageMirror.SafeSettings calldata _proposedSettings) public {
    _updateLatestVerifiedSettings(_safe, _proposedSettings);
  }

  function bytesToBytes32(bytes memory _bytes) public pure returns (bytes32 _bytes32) {
    _bytes32 = _bytesToBytes32(_bytes);
  }

  function extractStorageRootAndVerifyUpdateTest(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorAccountProof,
    bytes memory _storageMirrorStorageProof,
    SafeTxnParams calldata _arbitraryTxnParams
  ) external {
    STORAGE_MIRROR_ROOT_REGISTRY.proposeAndVerifyStorageMirrorStorageRoot(_storageMirrorAccountProof);
    proposeAndVerifyUpdateTest(_safe, _proposedSettings, _storageMirrorStorageProof, _arbitraryTxnParams);
  }

  // NOTE: Needs to match the proposeAndVerify function logic with the fake MPT because we cant mock librariers
  function proposeAndVerifyUpdateTest(
    address _safe,
    IStorageMirror.SafeSettings calldata _proposedSettings,
    bytes memory _storageMirrorStorageProof,
    IVerifierModule.SafeTxnParams calldata _safeTxnParams
  ) public {
    bytes32 _hashedProposedSettings = verifyNewSettings(_safe, _proposedSettings, _storageMirrorStorageProof);

    // If we dont revert from the _verifyNewSettings() call, then we can update the safe

    updateLatestVerifiedSettings(_safe, _proposedSettings);

    // Call the arbitrary transaction
    ISafe(_safe).execTransaction(
      _safeTxnParams.to,
      _safeTxnParams.value,
      _safeTxnParams.data,
      _safeTxnParams.operation,
      _safeTxnParams.safeTxGas,
      _safeTxnParams.baseGas,
      _safeTxnParams.gasPrice,
      _safeTxnParams.gasToken,
      _safeTxnParams.refundReceiver,
      _safeTxnParams.signatures
    );

    // Pay incentives
    // TODO: Calculations for incentives so its not hardcoded to 1e18
    ISafe(_safe).execTransactionFromModule(msg.sender, 1e18, '', Enum.Operation.Call);

    // Make the storage updates at the end of the call to save gas in a revert scenario
    latestVerifiedSettings[_safe] = _hashedProposedSettings;
    latestVerifiedSettingsTimestamp[_safe] = block.timestamp;

    emit VerifiedUpdate(_safe, _hashedProposedSettings);
  }

  // NOTE: Should match the function from the verifier but externalizes the library calls
  function extractStorageMirrorStorageRootTest(
    bytes memory _storageMirrorAccountProof,
    bytes memory _blockHeader
  ) external view returns (bytes32 _storageRoot) {
    StateVerifier.BlockHeader memory _parsedBlockHeader = mpt.verifyBlockHeader(_blockHeader);

    bytes memory _rlpAccount = mpt.extractProofValue(
      _parsedBlockHeader.stateRootHash,
      abi.encodePacked(keccak256(abi.encode(STORAGE_MIRROR))),
      _storageMirrorAccountProof
    );

    _storageRoot = mpt.extractStorageRootFromAccount(_rlpAccount);
  }
}

abstract contract Base is Test {
  IStorageMirrorRootRegistry internal _storageMirrorRegistry =
    IStorageMirrorRootRegistry(makeAddr('storageMirrorRegistry'));
  address internal _storageMirror = makeAddr('storageMirror');
  address internal _fakeSafe = makeAddr('fakeSafe');

  TestMPT public mpt = new TestMPT();
  TestVerifierModule public verifierModule = new TestVerifierModule(_storageMirrorRegistry, _storageMirror, mpt);

  event VerifiedUpdate(address _safe, bytes32 _verifiedHash);
}

contract UnitUpdateSettings is Base {
  function testUpdateSettingsAddsOwners() public {
    address[] memory _oldOwners = new address[](2);
    _oldOwners[0] = address(0x2);
    _oldOwners[1] = address(0x3);

    address[] memory _newOwners = new address[](3);
    _newOwners[0] = address(0x2);
    _newOwners[1] = address(0x3);
    _newOwners[2] = address(0x4);

    IStorageMirror.SafeSettings memory _newSettings = IStorageMirror.SafeSettings({owners: _newOwners, threshold: 2});

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(2));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector, address(0x4)), abi.encode(false));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );
    vm.expectCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      )
    );

    verifierModule.updateLatestVerifiedSettings(_fakeSafe, _newSettings);
  }

  function testUpdateSettingsRemovesOwners() public {
    address[] memory _newOwners = new address[](2);
    _newOwners[0] = address(0x2);
    _newOwners[1] = address(0x3);

    address[] memory _oldOwners = new address[](3);
    _oldOwners[0] = address(0x2);
    _oldOwners[1] = address(0x3);
    _oldOwners[2] = address(0x4);

    IStorageMirror.SafeSettings memory _newSettings = IStorageMirror.SafeSettings({owners: _newOwners, threshold: 2});

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(2));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.removeOwner.selector, address(0x4), address(0x3), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );
    vm.expectCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.removeOwner.selector, address(0x4), address(0x3), 2),
        Enum.Operation.Call
      )
    );

    verifierModule.updateLatestVerifiedSettings(_fakeSafe, _newSettings);
  }

  function testRemovesOwnerIfPreviousOwnerIsSentinel() public {
    address[] memory _newOwners = new address[](2);
    _newOwners[0] = address(0x3);
    _newOwners[1] = address(0x4);

    address[] memory _oldOwners = new address[](3);
    _oldOwners[0] = address(0x2);
    _oldOwners[1] = address(0x3);
    _oldOwners[2] = address(0x4);

    IStorageMirror.SafeSettings memory _newSettings = IStorageMirror.SafeSettings({owners: _newOwners, threshold: 2});

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(2));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.removeOwner.selector, address(0x2), address(0x1), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );
    vm.expectCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.removeOwner.selector, address(0x2), address(0x1), 2),
        Enum.Operation.Call
      )
    );

    verifierModule.updateLatestVerifiedSettings(_fakeSafe, _newSettings);
  }

  function testWillChangeThresholdIfNoUpdateIsMade() public {
    address[] memory _newOwners = new address[](3);
    _newOwners[0] = address(0x3);
    _newOwners[1] = address(0x4);
    _newOwners[2] = address(0x2);

    address[] memory _oldOwners = new address[](3);
    _oldOwners[0] = address(0x2);
    _oldOwners[1] = address(0x3);
    _oldOwners[2] = address(0x4);

    IStorageMirror.SafeSettings memory _newSettings = IStorageMirror.SafeSettings({owners: _newOwners, threshold: 3});

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(2));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.changeThreshold.selector, 3),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );
    vm.expectCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.changeThreshold.selector, 3),
        Enum.Operation.Call
      )
    );

    verifierModule.updateLatestVerifiedSettings(_fakeSafe, _newSettings);
  }
}

contract UnitMerklePatriciaTree is Base {
  function testMPTIsCalledWithCorrectParams(IStorageMirror.SafeSettings memory _fakeSettings) public {
    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    vm.expectCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      )
    );

    bytes32 _hashedProposedSettings = verifierModule.verifyNewSettings(_fakeSafe, _fakeSettings, _storageProof);

    assertEq(
      abi.encodePacked(_hashedProposedSettings),
      abi.encodePacked(_expectedOutput),
      'Hashed proposed settings should match expected output'
    );
  }

  function testMPTRevertsIfSettingsDontMatch(IStorageMirror.SafeSettings memory _fakeSettings) public {
    vm.assume(_fakeSettings.owners.length > 1 && _fakeSettings.threshold >= 1 && _fakeSettings.owners[0] != address(0));

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput =
      abi.encodePacked(keccak256(abi.encode(IStorageMirror.SafeSettings({owners: new address[](1), threshold: 1}))));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    vm.expectRevert(IVerifierModule.SettingsDontMatch.selector);
    verifierModule.verifyNewSettings(_fakeSafe, _fakeSettings, _storageProof);
  }

  function testMPTRevertsIfOutputIsLongerThen32Bytes(IStorageMirror.SafeSettings memory _fakeSettings) public {
    vm.assume(_fakeSettings.owners.length > 1 && _fakeSettings.threshold >= 1 && _fakeSettings.owners[0] != address(0));

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)), uint256(18));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    vm.expectRevert(IVerifierModule.BytesToBytes32Failed.selector);
    verifierModule.verifyNewSettings(_fakeSafe, _fakeSettings, _storageProof);
  }

  function testExecTransactionIsCalledAfterVerification(IStorageMirror.SafeSettings memory _fakeSettings) public {
    address[] memory _oldOwners = _fakeSettings.owners;

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(_fakeSettings.threshold));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    IVerifierModule.SafeTxnParams memory _txDetails = IVerifierModule.SafeTxnParams({
      to: _fakeSafe,
      value: 0,
      data: abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: ''
    });

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(ISafe.execTransactionFromModule.selector, address(this), 1e18, '', Enum.Operation.Call),
      abi.encode(true)
    );

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransaction.selector,
        _txDetails.to,
        _txDetails.value,
        _txDetails.data,
        _txDetails.operation,
        _txDetails.safeTxGas,
        _txDetails.baseGas,
        _txDetails.gasPrice,
        _txDetails.gasToken,
        _txDetails.refundReceiver,
        _txDetails.signatures
      ),
      abi.encode(true)
    );

    vm.expectCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransaction.selector,
        _txDetails.to,
        _txDetails.value,
        _txDetails.data,
        _txDetails.operation,
        _txDetails.safeTxGas,
        _txDetails.baseGas,
        _txDetails.gasPrice,
        _txDetails.gasToken,
        _txDetails.refundReceiver,
        _txDetails.signatures
      )
    );

    verifierModule.proposeAndVerifyUpdateTest(_fakeSafe, _fakeSettings, _storageProof, _txDetails);
  }

  function testEmitsEvent(IStorageMirror.SafeSettings memory _fakeSettings) public {
    address[] memory _oldOwners = _fakeSettings.owners;

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(_fakeSettings.threshold));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    IVerifierModule.SafeTxnParams memory _txDetails = IVerifierModule.SafeTxnParams({
      to: _fakeSafe,
      value: 0,
      data: abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: ''
    });

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(ISafe.execTransactionFromModule.selector, address(this), 1e18, '', Enum.Operation.Call),
      abi.encode(true)
    );

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransaction.selector,
        _txDetails.to,
        _txDetails.value,
        _txDetails.data,
        _txDetails.operation,
        _txDetails.safeTxGas,
        _txDetails.baseGas,
        _txDetails.gasPrice,
        _txDetails.gasToken,
        _txDetails.refundReceiver,
        _txDetails.signatures
      ),
      abi.encode(true)
    );

    vm.expectEmit(true, true, true, true);
    emit VerifiedUpdate(_fakeSafe, verifierModule.bytesToBytes32(_expectedOutput));

    verifierModule.proposeAndVerifyUpdateTest(_fakeSafe, _fakeSettings, _storageProof, _txDetails);
  }

  function testStorageIsUpdated(IStorageMirror.SafeSettings memory _fakeSettings) public {
    uint256 _fakeTimestamp = 1_234_567_890;

    vm.warp(_fakeTimestamp);

    address[] memory _oldOwners = _fakeSettings.owners;

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(_fakeSettings.threshold));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    IVerifierModule.SafeTxnParams memory _txDetails = IVerifierModule.SafeTxnParams({
      to: _fakeSafe,
      value: 0,
      data: abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: ''
    });

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(ISafe.execTransactionFromModule.selector, address(this), 1e18, '', Enum.Operation.Call),
      abi.encode(true)
    );

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransaction.selector,
        _txDetails.to,
        _txDetails.value,
        _txDetails.data,
        _txDetails.operation,
        _txDetails.safeTxGas,
        _txDetails.baseGas,
        _txDetails.gasPrice,
        _txDetails.gasToken,
        _txDetails.refundReceiver,
        _txDetails.signatures
      ),
      abi.encode(true)
    );

    verifierModule.proposeAndVerifyUpdateTest(_fakeSafe, _fakeSettings, _storageProof, _txDetails);

    assertEq(
      verifierModule.latestVerifiedSettings(_fakeSafe),
      verifierModule.bytesToBytes32(_expectedOutput),
      'Storage should be updated'
    );
    assertEq(verifierModule.latestVerifiedSettingsTimestamp(_fakeSafe), _fakeTimestamp, 'Timestamp should be updated');
  }

  function testExtractRootAndVerifyUpdate(
    IStorageMirror.SafeSettings memory _fakeSettings,
    bytes memory _accountProof
  ) public {
    uint256 _fakeTimestamp = 1_234_567_890;

    vm.warp(_fakeTimestamp);
    vm.assume(_accountProof.length > 0);

    address[] memory _oldOwners = _fakeSettings.owners;

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getOwners.selector), abi.encode(_oldOwners));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.getThreshold.selector), abi.encode(_fakeSettings.threshold));

    vm.mockCall(_fakeSafe, abi.encodeWithSelector(ISafe.isOwner.selector), abi.encode(true));

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransactionFromModule.selector,
        _fakeSafe,
        0,
        abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
        Enum.Operation.Call
      ),
      abi.encode(true)
    );

    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(1))));

    bytes memory _storageProof = hex'e10e2d527612073b26eecdfd717e6a320f';

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(IStorageMirrorRootRegistry.latestVerifiedStorageRoot.selector),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _safeSettingsSlot = keccak256(abi.encode(_fakeSafe, 0));

    bytes32 _safeSettingsSlotHash = keccak256(abi.encode(_safeSettingsSlot));

    bytes memory _expectedOutput = abi.encodePacked(keccak256(abi.encode(_fakeSettings)));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector, _fakeStorageRoot, abi.encodePacked(_safeSettingsSlotHash), _storageProof
      ),
      abi.encode(_expectedOutput)
    );

    IVerifierModule.SafeTxnParams memory _txDetails = IVerifierModule.SafeTxnParams({
      to: _fakeSafe,
      value: 0,
      data: abi.encodeWithSelector(ISafe.addOwnerWithThreshold.selector, address(0x4), 2),
      operation: Enum.Operation.Call,
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: address(0),
      refundReceiver: payable(address(0)),
      signatures: ''
    });

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(ISafe.execTransactionFromModule.selector, address(this), 1e18, '', Enum.Operation.Call),
      abi.encode(true)
    );

    vm.mockCall(
      _fakeSafe,
      abi.encodeWithSelector(
        ISafe.execTransaction.selector,
        _txDetails.to,
        _txDetails.value,
        _txDetails.data,
        _txDetails.operation,
        _txDetails.safeTxGas,
        _txDetails.baseGas,
        _txDetails.gasPrice,
        _txDetails.gasToken,
        _txDetails.refundReceiver,
        _txDetails.signatures
      ),
      abi.encode(true)
    );

    vm.mockCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(
        IStorageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot.selector, _accountProof
      ),
      abi.encode()
    );

    vm.expectCall(
      address(_storageMirrorRegistry),
      abi.encodeWithSelector(
        IStorageMirrorRootRegistry.proposeAndVerifyStorageMirrorStorageRoot.selector, _accountProof
      )
    );

    verifierModule.extractStorageRootAndVerifyUpdateTest(
      _fakeSafe, _fakeSettings, _accountProof, _storageProof, _txDetails
    );
  }
}

contract UnitStorageRoot is Base {
  function testStorageMirrorStorageRootIsCalledWithCorrectParams(bytes memory _accountProof) public {
    vm.assume(_accountProof.length > 0);

    StateVerifier.BlockHeader memory _fakeHeader =
      StateVerifier.BlockHeader({hash: bytes32(uint256(1)), stateRootHash: bytes32(uint256(2)), number: 500});

    bytes memory _rlpHeader = abi.encodePacked(_fakeHeader.hash);

    vm.mockCall(
      address(mpt), abi.encodeWithSelector(TestMPT.verifyBlockHeader.selector, _rlpHeader), abi.encode(_fakeHeader)
    );

    bytes memory _fakeAccount = abi.encodePacked(keccak256(abi.encode(bytes32(uint256(3)))));
    bytes32 _fakeStorageRoot = keccak256(abi.encode(bytes32(uint256(4))));

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(
        TestMPT.extractProofValue.selector,
        _fakeHeader.stateRootHash,
        abi.encodePacked(keccak256(abi.encode(_storageMirror))),
        _accountProof
      ),
      abi.encode(_fakeAccount)
    );

    vm.mockCall(
      address(mpt),
      abi.encodeWithSelector(TestMPT.extractStorageRootFromAccount.selector, abi.encodePacked(_fakeAccount)),
      abi.encode(_fakeStorageRoot)
    );

    bytes32 _storageRoot = verifierModule.extractStorageMirrorStorageRootTest(_accountProof, _rlpHeader);

    assertEq(_storageRoot, _fakeStorageRoot, 'Storage root should match');
  }
}
