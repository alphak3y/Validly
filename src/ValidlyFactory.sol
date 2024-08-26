// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Validly } from "src/Validly.sol";
import { IProtocolFactory } from "@valantis-core/protocol-factory/interfaces/IProtocolFactory.sol";
import { SovereignPoolConstructorArgs } from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import { ISovereignPool } from "@valantis-core/pools/interfaces/ISovereignPool.sol";

contract ValidlyFactory {

    /************************************************
    *  ERRORS
    ***********************************************/

    error ValidlyFactory__constructor_invalidFeeBips();
    error ValidlyFactory__deploy_failedDeployment();
    error ValidlyFactory__deploy_alreadyDeployed();

    /************************************************
    *  IMMUTABLES
    ***********************************************/

    /// @notice The protocol factory contract used for deploying pools
    /// @dev This is set in the constructor and cannot be changed
    IProtocolFactory immutable public protocolFactory;

    /// @notice The fee percentage for the Validly pool
    /// @dev This is set in the constructor and cannot be changed
    uint256 immutable public feeBips;

    /************************************************
    *  STORAGE
    ***********************************************/

    /// @notice Mapping from pool keys to pool addresses
    mapping(bytes32 key => address pool) public pools;

    /************************************************
    *  CONSTRUCTOR
    ***********************************************/
    constructor(address _protocolFactory, uint256 _feeBips) {
        protocolFactory = IProtocolFactory(_protocolFactory);
        
        if (_feeBips > 10000) {
            revert ValidlyFactory__constructor_invalidFeeBips();
        }

        feeBips = _feeBips;
    }


    /************************************************
    *  EXTERNAL FUNCTIONS
    ***********************************************/

    /// @notice Deploys a new Validly pool for a given token pair
    /// @dev Tokens are sorted internally to ensure consistent pool keys
    /// @param _token0 The address of the first token in the pair
    /// @param _token1 The address of the second token in the pair
    /// @param _isStable Boolean indicating if the pool should be stable or volatile
    /// @custom:error ValidlyFactory__deploy_alreadyDeployed Thrown if a pool for the given token pair and stability type already exists
    /// @custom:error ValidlyFactory__deploy_failedDeployment Thrown if the Validly contract deployment fails
    function createPair(address _token0, address _token1, bool _isStable) external returns (address) {

        (_token0, _token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

        bytes32 poolKey = _poolKey(_token0, _token1, _isStable);
        
        if(pools[poolKey] != address(0)){
            revert ValidlyFactory__deploy_alreadyDeployed(); 
        }

        SovereignPoolConstructorArgs memory args = SovereignPoolConstructorArgs(
            _token0,
            _token1,
            address(protocolFactory),
            address(this),
            address(0),
            address(0),
            false,
            false,
            0,
            0,
            feeBips
        );

        address pool = protocolFactory.deploySovereignPool(args);

        Validly validly = new Validly{salt: poolKey}(pool, _isStable);

        if(address(validly) == address(0)){
            revert ValidlyFactory__deploy_failedDeployment();
        }

        ISovereignPool(pool).setALM(address(validly));    

        ISovereignPool(pool).setPoolManager(address(0));

        pools[poolKey] = pool;

        return address(validly);
    }

    /************************************************
    *  INTERNAL FUNCTIONS
    ***********************************************/

    function _poolKey(address token0, address token1, bool isStable) internal pure returns (bytes32 key) {
        key = keccak256(abi.encode(token0, token1, isStable));
    }

}