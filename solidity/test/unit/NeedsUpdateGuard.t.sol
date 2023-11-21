// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {Enum} from 'safe-contracts/common/Enum.sol';
import {NeedsUpdateGuard} from 'contracts/NeedsUpdateGuard.sol';
import {IVerifierModule} from 'interfaces/IVerifierModule.sol';

abstract contract Base is Test {
  event TimeTillNeedsUpdateChanged(address indexed _safe, uint256 _newSecuritySettings);

  error NeedsUpdateGuard_NeedsUpdate();

  address public safe;
  IVerifierModule public verifierModule;
  NeedsUpdateGuard public needsUpdateGuard;

  function setUp() public {
    safe = makeAddr('safe');
    verifierModule = IVerifierModule(makeAddr('verifierModule'));
    needsUpdateGuard = new NeedsUpdateGuard(verifierModule);
    // Warp to 2022-01-01 00:00:00 UTC
    vm.warp(1_641_070_800);
  }
}

contract UnitNeedsUpdateGuard is Base {
  function testCheckTransaction(address _to, uint256 _value, bytes memory _data) public {
    // Set security settings
    vm.prank(safe);
    needsUpdateGuard.updateSecuritySettings(200);

    // Mock latest verified settings timestamp to current timestamp - 100
    uint256 _currentTimeStamp = block.timestamp;
    vm.mockCall(
      address(verifierModule),
      abi.encodeWithSelector(IVerifierModule.latestVerifiedSettingsTimestamp.selector, safe),
      abi.encode(_currentTimeStamp - 100)
    );

    vm.expectCall(
      address(verifierModule), abi.encodeWithSelector(IVerifierModule.latestVerifiedSettingsTimestamp.selector, safe)
    );

    vm.prank(safe);
    needsUpdateGuard.checkTransaction(
      _to, _value, _data, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', safe
    );
  }

  function testCheckTransactionReverts(address _to, uint256 _value, bytes memory _data) public {
    // Set security settings
    vm.prank(safe);
    needsUpdateGuard.updateSecuritySettings(200);

    // Mock latest verified settings timestamp to current timestamp - 1_000 to make the check fail
    uint256 _currentTimeStamp = block.timestamp;
    vm.mockCall(
      address(verifierModule),
      abi.encodeWithSelector(IVerifierModule.latestVerifiedSettingsTimestamp.selector, safe),
      abi.encode(_currentTimeStamp - 1000)
    );

    vm.expectCall(
      address(verifierModule), abi.encodeWithSelector(IVerifierModule.latestVerifiedSettingsTimestamp.selector, safe)
    );

    vm.expectRevert(abi.encodeWithSelector(NeedsUpdateGuard.NeedsUpdateGuard_NeedsUpdate.selector));

    vm.prank(safe);
    needsUpdateGuard.checkTransaction(
      _to, _value, _data, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), '', safe
    );
  }

  function testCheckAfterExecution(bytes32 _txHash) public {
    vm.prank(safe);
    needsUpdateGuard.checkAfterExecution(_txHash, true);
  }

  function testUpdateSecuritySettings(uint256 _newSettings) public {
    vm.expectEmit(true, true, true, true);
    emit TimeTillNeedsUpdateChanged(safe, _newSettings);

    vm.prank(safe);
    needsUpdateGuard.updateSecuritySettings(_newSettings);

    assertEq(needsUpdateGuard.timeTillNeedsUpdate(safe), _newSettings, 'Security settings should be updated');
  }
}
