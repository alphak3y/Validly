// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployValidlyBase} from 'scripts/base/DeployValidlyBase.sol';
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Validly} from "src/Validly.sol";

contract Default is DeployValidlyBase {
  ERC20Mock public token0;
  ERC20Mock public token1;

  Validly volatilePair;
  Validly stablePair;

  address volatilePool;
  address stablePool;

  function run() external {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    token0 = new ERC20Mock();
    token1 = new ERC20Mock();

    _deployFactory();

    (token0, token1) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

    (stablePair, stablePool) = _deployStablePair(address(token1), address(token0));
    (volatilePair, volatilePool) = _deployVolatilePair(address(token0), address(token1));

    vm.stopBroadcast();
  }
}