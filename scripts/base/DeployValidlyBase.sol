// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import {SovereignPoolFactory} from "@valantis-core/pools/factories/SovereignPoolFactory.sol";
import {SovereignPool} from "@valantis-core/pools/SovereignPool.sol";
import {ProtocolFactory} from "@valantis-core/protocol-factory/ProtocolFactory.sol";
import {Validly} from "src/Validly.sol";
import {ValidlyFactory} from "src/ValidlyFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract DeployValidlyBase is Script {
  using stdJson for string;

  ProtocolFactory protocolFactory;
  SovereignPoolFactory poolFactory;
  ValidlyFactory validlyFactory;

  function _deployProtocolFactory() public {
    protocolFactory = new ProtocolFactory(vm.envAddress('SENDER'));

    poolFactory = new SovereignPoolFactory();

    protocolFactory.setSovereignPoolFactory(address(poolFactory));
  }

  function _deployValidlyFactory(uint256[] memory feeTiers, uint256 defaultPoolManagerFeeBips) public {
    validlyFactory = new ValidlyFactory(address(protocolFactory), feeTiers, defaultPoolManagerFeeBips);
  }

  function _createPair(address tokenA, address tokenB, bool isStable, uint16 feeBips) internal returns (Validly, address) {
    Validly pair = Validly(validlyFactory.createPair(address(tokenA), address(tokenB), isStable, feeBips));
    return (pair, address(pair.pool()));
  }

  function _faucetTokens(
    address[] memory tokens,
    uint256[] memory amounts,
    address[] memory recipients
  ) 
    internal
  {
    for (uint i; i < recipients.length; ){
      for (uint j; j < tokens.length; ){
        ERC20Mock(tokens[j]).mint(recipients[i], amounts[j]);
        unchecked {
          j++;
        }
      }
      unchecked {
        i++;
      }
    }
  }
}
