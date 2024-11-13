// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IProtocolFactory} from "@valantis-core/protocol-factory/interfaces/IProtocolFactory.sol";

interface IValidlyFactory {
    /**
     *  EVENTS
     */
    event FeesClaimed(address indexed pool);
    event PoolCreated(address indexed pool, address indexed token0, address indexed token1, bool isStable, uint16 fee);
    event PoolManagerFeeBipsSet(address indexed pool, uint256 feeBips);
    event TokenClaimed(address indexed token, address indexed recipient, uint256 amount);

    /**
     *  EXTERNAL FUNCTIONS
     */
    function protocolFactory() external view returns (IProtocolFactory);

    function feeTiers(uint256 fee) external view returns (bool enabled);
}
