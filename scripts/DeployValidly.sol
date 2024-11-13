// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeployValidlyBase} from 'scripts/base/DeployValidlyBase.sol';
import {Validly} from "src/Validly.sol";

contract Default is DeployValidlyBase {
  function run() external {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _deployProtocolFactory();

    uint256[] memory feeTiers = new uint256[](3);
    
    feeTiers[0] = 5;
    feeTiers[1] = 30;
    feeTiers[2] = 100;

    uint256 defaultPoolManagerFeeBips = 0;

    _deployValidlyFactory(feeTiers, defaultPoolManagerFeeBips);

    vm.stopBroadcast();
  }
}