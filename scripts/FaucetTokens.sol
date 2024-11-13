// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {DeployValidlyBase} from 'scripts/base/DeployValidlyBase.sol';

contract Default is DeployValidlyBase {
  function run() external {
    address[] memory tokens = new address[](2);

    tokens[0] = 0x060E976B4104960d44B11204221AB98e095DDc93; // TKNA
    tokens[1] = 0xA71D153FBAFb5E94c6716F51E001daF46A93a9eE; // TKNB

    uint256[] memory amounts = new uint256[](2);

    amounts[0] = 1000e18;
    amounts[1] = 1000e18;

    address[] memory recipients = new address[](1);

    recipients[0] = 0x2fCf555c4C508c2e358F373A4B6E25F8491928b0;

    console.log('Validly Token Fauceting');
    console.log('sender', msg.sender);

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _faucetTokens(
       tokens,
       amounts,
       recipients 
    );

    vm.stopBroadcast();
  }
}