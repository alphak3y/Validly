// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IProtocolFactory} from "@valantis-core/protocol-factory/interfaces/IProtocolFactory.sol";

interface IValidlyFactory {
    /**
     *  EVENTS
     */
    event FeesClaimed(address indexed pool);
    event PoolCreated(address indexed pool, address indexed token0, address indexed token1, bool isStable, uint16 feeBips);
    event PoolManagerFeeBipsSet(address indexed pool, uint256 feeBips);
    event DefaultPoolManagerFeeBipsSet(uint256 feeBips);
    event FeeTierEnabled(uint256 feeBips);
    event TokenClaimed(address indexed token, address indexed recipient, uint256 amount);

    /**
     *  EXTERNAL FUNCTIONS
     */
    function getPoolAddresses(address token0, address token1, bool isStable, uint16 fee)
        external
        view
        returns (address validlyPool, address sovereignPool);

    function feeTiers(uint256 fee) external view returns (bool enabled);

    function protocolFactory() external view returns (IProtocolFactory);
}
