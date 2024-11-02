// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployValidlyBase} from 'scripts/base/DeployValidlyBase.sol';
import {Validly} from "src/Validly.sol";

contract Default is DeployValidlyBase {
  function run() external {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _deployFactory();

    vm.stopBroadcast();
  }
}