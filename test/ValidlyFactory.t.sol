// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Validly} from "../src/Validly.sol";
import {ValidlyFactory} from "../src/ValidlyFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ProtocolFactory} from "@valantis-core/protocol-factory/ProtocolFactory.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";
import {
    SovereignPoolSwapParams,
    SovereignPoolConstructorArgs
} from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import {SovereignPoolFactory} from "@valantis-core/pools/factories/SovereignPoolFactory.sol";

contract ValidlyFactoryTest is Test {
    ValidlyFactory public factory;
    ERC20Mock public token0;
    ERC20Mock public token1;
    ProtocolFactory protocolFactory;

    function setUp() public {
        // Create dummy tokens
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        protocolFactory = new ProtocolFactory(address(this));

        SovereignPoolFactory poolFactory = new SovereignPoolFactory();

        protocolFactory.setSovereignPoolFactory(address(poolFactory));

        // Create ValidlyFactory
        factory = new ValidlyFactory(address(protocolFactory), 1);
    }

    function test_constructor() public {
        assertEq(address(factory.protocolFactory()), address(protocolFactory));
        assertEq(factory.feeBips(), 1);

        vm.expectRevert(ValidlyFactory.ValidlyFactory__constructor_invalidFeeBips.selector);

        new ValidlyFactory(address(protocolFactory), 10001);
    }

    function test_createPair() public {
        factory.createPair(address(token0), address(token1), true);

        vm.expectRevert(ValidlyFactory.ValidlyFactory__createPair_alreadyDeployed.selector);

        factory.createPair(address(token0), address(token1), true);
    }

    function test_createPool() public {
        SovereignPoolConstructorArgs memory args = SovereignPoolConstructorArgs(
            address(token0),
            address(token1),
            address(protocolFactory),
            address(this),
            address(0),
            address(0),
            true,
            true,
            5,
            5,
            0
        );

        address pair = factory.createPool(args, true);

        assertEq(Validly(pair).pool().token0(), address(token0));
        assertEq(Validly(pair).pool().token1(), address(token1));
    }
}
