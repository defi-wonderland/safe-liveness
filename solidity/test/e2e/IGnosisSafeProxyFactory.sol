// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {SafeProxy} from 'safe-contracts/proxies/SafeProxy.sol';
import {IProxyCreationCallback} from 'safe-contracts/proxies/IProxyCreationCallback.sol';

interface IGnosisSafeProxyFactory {
  event ProxyCreation(SafeProxy proxy, address singleton);

  function createProxy(address singleton, bytes memory data) external returns (SafeProxy proxy);

  function createProxyWithNonce(
    address _singleton,
    bytes memory initializer,
    uint256 saltNonce
  ) external returns (SafeProxy proxy);

  function createProxyWithCallback(
    address _singleton,
    bytes memory initializer,
    uint256 saltNonce,
    IProxyCreationCallback callback
  ) external returns (SafeProxy proxy);

  function calculateCreateProxyWithNonceAddress(
    address _singleton,
    bytes calldata initializer,
    uint256 saltNonce
  ) external returns (SafeProxy proxy);
}
