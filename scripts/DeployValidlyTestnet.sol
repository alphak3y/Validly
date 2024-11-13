// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeployValidlyBase} from 'scripts/base/DeployValidlyBase.sol';
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Validly} from "src/Validly.sol";

contract Default is DeployValidlyBase {
  ERC20Mock public token0;
  ERC20Mock public token1;

  Validly volatilePair;
  Validly stablePair;
  Validly exoticPair;

  address volatilePool;
  address stablePool;
  address exoticPool;

  function run() external {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _deployProtocolFactory();

    uint256[] memory feeTiers = new uint256[](3);
    
    feeTiers[0] = 5;
    feeTiers[1] = 30;
    feeTiers[2] = 100;

    uint256 defaultPoolManagerFeeBips = 10;

    _deployValidlyFactory(feeTiers, defaultPoolManagerFeeBips);

    token0 = ERC20Mock(0x060E976B4104960d44B11204221AB98e095DDc93);
    token1 = ERC20Mock(0xA71D153FBAFb5E94c6716F51E001daF46A93a9eE);

    (token0, token1) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

    (stablePair, stablePool) = _createPair(address(token1), address(token0), true, 5);
    (volatilePair, volatilePool) = _createPair(address(token0), address(token1), false, 30);
    (exoticPair, exoticPool) = _createPair(address(token0), address(token1), false, 100);

    vm.stopBroadcast();
  }
}