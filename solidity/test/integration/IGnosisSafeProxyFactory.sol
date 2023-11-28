// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {IProxyCreationCallback} from 'safe-contracts/proxies/IProxyCreationCallback.sol';

interface IGnosisSafeProxyFactory {
  event ProxyCreation(SafeProxy _proxy, address _singleton);

  function createProxy(address _singleton, bytes memory _data) external returns (SafeProxy _proxy);

  function createProxyWithNonce(
    address _singleton,
    bytes memory _initializer,
    uint256 _saltNonce
  ) external returns (SafeProxy _proxy);

  function createProxyWithCallback(
    address _singleton,
    bytes memory _initializer,
    uint256 _saltNonce,
    IProxyCreationCallback _callback
  ) external returns (SafeProxy _proxy);

  function calculateCreateProxyWithNonceAddress(
    address _singleton,
    bytes calldata _initializer,
    uint256 _saltNonce
  ) external returns (SafeProxy _proxy);
}
