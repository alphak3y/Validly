// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import {SovereignPoolFactory} from "@valantis-core/pools/factories/SovereignPoolFactory.sol";
import {SovereignPool} from "@valantis-core/pools/SovereignPool.sol";
import {ProtocolFactory} from "@valantis-core/protocol-factory/ProtocolFactory.sol";
import {Validly} from "src/Validly.sol";
import {ValidlyFactory} from "src/ValidlyFactory.sol";

abstract contract DeployValidlyBase is Script {
  using stdJson for string;

  ValidlyFactory public factory;
  ProtocolFactory protocolFactory;
  SovereignPoolFactory poolFactory;

  function _deployFactory() public {
    protocolFactory = new ProtocolFactory(vm.envAddress('SENDER'));

    poolFactory = new SovereignPoolFactory();

    protocolFactory.setSovereignPoolFactory(address(poolFactory));

    // Create ValidlyFactory
    factory = new ValidlyFactory(address(protocolFactory), 1);
  }

  function _deployStablePair(address tokenA, address tokenB) internal returns (Validly, address) {
    Validly stablePair = Validly(factory.createPair(address(tokenA), address(tokenB), true));
    return (stablePair, address(stablePair.pool()));
  }

  function _deployVolatilePair(address tokenA, address tokenB) internal returns (Validly, address) {
    Validly volatilePair = Validly(factory.createPair(address(tokenA), address(tokenB), false));
    return (volatilePair, address(volatilePair.pool()));
  }
}
