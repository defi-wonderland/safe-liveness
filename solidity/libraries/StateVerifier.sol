// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {RLPReader} from 'solidity-rlp/contracts/RLPReader.sol';

library StateVerifier {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

  error InvalidBlockHeader();
  error InvalidAccount();

  uint256 internal constant _HEADER_STATE_ROOT_INDEX = 3;
  uint256 internal constant _HEADER_NUMBER_INDEX = 8;

  struct BlockHeader {
    bytes32 hash;
    bytes32 stateRootHash;
    uint256 number;
  }

  function verifyBlockHeader(bytes memory _rlpBlockHeader)
    internal
    pure
    returns (BlockHeader memory _parsedBlockHeader)
  {
    RLPReader.RLPItem[] memory headerFields = _rlpBlockHeader.toRlpItem().toList();

    // Sanity check to ensure that the block header is long enough to be valid
    if (headerFields.length <= _HEADER_NUMBER_INDEX) revert InvalidBlockHeader();

    _parsedBlockHeader.stateRootHash = bytes32(headerFields[_HEADER_STATE_ROOT_INDEX].toUint());
    _parsedBlockHeader.number = headerFields[_HEADER_NUMBER_INDEX].toUint();
    _parsedBlockHeader.hash = keccak256(_rlpBlockHeader);
  }

  function extractStorageRootFromAccount(bytes memory _rlpAccount) internal pure returns (bytes32 _storageRoot) {
    // Non-inclusive proof
    if (_rlpAccount.length == 0) {
      return bytes32(0);
    }

    RLPReader.RLPItem[] memory _accountFields = _rlpAccount.toRlpItem().toList();

    // Sanity check to ensure that the account verification happend as expected
    if (_accountFields.length != 4) revert InvalidBlockHeader();

    _storageRoot = bytes32(_accountFields[2].toUint());
  }
}
