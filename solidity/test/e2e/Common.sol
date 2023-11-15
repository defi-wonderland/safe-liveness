// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/solidity/test/DSTestPlus.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {StorageMirror} from 'contracts/StorageMirror.sol';
import {UpdateStorageMirrorGuard} from 'contracts/UpdateStorageMirrorGuard.sol';
import {IGuardCallbackModule} from 'interfaces/IGuardCallbackModule.sol';
import {IGnosisSafeProxyFactory} from 'test/e2e/IGnosisSafeProxyFactory.sol';
import {TestConstants} from 'test/TestConstants.sol';

contract CommonE2EBase is DSTestPlus, TestConstants {
  uint256 internal constant _FORK_BLOCK = 15_452_788;

  address public deployer = makeAddr('deployer');
  address public safeOwner = makeAddr('safeOwner');
  address public proposer = makeAddr('proposer');

  StorageMirror public storageMirror;
  UpdateStorageMirrorGuard public updateStorageMirrorGuard;
  SafeProxy public safe;
  IGuardCallbackModule public guardCallbackModule = IGuardCallbackModule(makeAddr('guardCallbackModule'));
  IGnosisSafeProxyFactory public gnosisSafeProxyFactory = IGnosisSafeProxyFactory(GNOSIS_SAFE_PROXY_FACTORY);

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);

    vm.prank(safeOwner);
    safe = gnosisSafeProxyFactory.createProxy(GNOSIS_SAFE_SINGLETON, '');
    label(address(safe), 'SafeProxy');

    vm.prank(deployer);
    storageMirror = new StorageMirror();
    label(address(storageMirror), 'StorageMirror');

    vm.prank(deployer);
    updateStorageMirrorGuard = new UpdateStorageMirrorGuard(guardCallbackModule);
    label(address(updateStorageMirrorGuard), 'UpdateStorageMirrorGuard');
  }
}
