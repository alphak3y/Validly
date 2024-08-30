// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Validly} from "src/Validly.sol";
import {IProtocolFactory} from "@valantis-core/protocol-factory/interfaces/IProtocolFactory.sol";
import {SovereignPoolConstructorArgs} from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";

contract ValidlyFactory {
    /**
     *  ERRORS
     */
    error ValidlyFactory__constructor_invalidFeeBips();
    error ValidlyFactory__createPair_failedDeployment();
    error ValidlyFactory__createPair_alreadyDeployed();
    error ValidlyFactory__createPool_failedDeployment();
    error ValidlyFactory__setPoolManagerFees_unauthorized();

    /**
     *  IMMUTABLES
     */

    /**
     * @notice The protocol factory contract used for deploying pools
     *  @dev This is set in the constructor and cannot be changed
     */
    IProtocolFactory public immutable protocolFactory;

    /**
     * @notice The fee percentage for the Validly pool
     *  @dev This is set in the constructor and cannot be changed
     */
    uint256 public immutable feeBips;

    /**
     *  STORAGE
     */

    /**
     * @notice Mapping from pool keys to pool addresses
     */
    mapping(bytes32 key => address pool) public pools;

    /**
     *  CONSTRUCTOR
     */
    constructor(address _protocolFactory, uint256 _feeBips) {
        protocolFactory = IProtocolFactory(_protocolFactory);

        if (_feeBips == 0 || _feeBips > 10000) {
            revert ValidlyFactory__constructor_invalidFeeBips();
        }

        feeBips = _feeBips;
    }

    /**
     *  EXTERNAL FUNCTIONS
     */

    /**
     * @notice Deploys a new Validly pool for a given token pair
     * @dev Tokens are sorted internally to ensure consistent pool keys
     * @param _token0 The address of the first token in the pair
     * @param _token1 The address of the second token in the pair
     * @param _isStable Boolean indicating if the pool should be stable or volatile
     * @custom:error ValidlyFactory__createPair_alreadyDeployed Thrown if a pool for the given token pair and stability type already exists
     * @custom:error ValidlyFactory__createPair_failedDeployment Thrown if the Validly contract deployment fails
     * @custom:error ValidlyFactory__createPair_invalidFeeBips Thrown if the feeBips is not between 0 and 10000
     */
    function createPair(address _token0, address _token1, bool _isStable) external returns (address) {
        (_token0, _token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

        bytes32 poolKey = _poolKey(_token0, _token1, _isStable);

        if (pools[poolKey] != address(0)) {
            revert ValidlyFactory__createPair_alreadyDeployed();
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

        if (address(validly) == address(0)) {
            revert ValidlyFactory__createPair_failedDeployment();
        }

        ISovereignPool(pool).setALM(address(validly));

        pools[poolKey] = pool;

        return address(validly);
    }

    /**
     * @notice Creates a new Validly pool, mostly for rebase tokens, which is not indexed in pools mapping
     * @dev This function is used to create a pool given the SovereignPool constructor arguments
     * @param _args The constructor arguments for the SovereignPool
     * @param _isStable Boolean indicating if the pool should be stable or volatile
     * @custom:error ValidlyFactory__createPool_failedDeployment Thrown if the Validly contract deployment fails
     */
    function createPool(SovereignPoolConstructorArgs memory _args, bool _isStable) external returns (address validly) {
        _args.poolManager = address(this);

        address pool = protocolFactory.deploySovereignPool(_args);

        validly = address(new Validly(pool, _isStable));

        if (address(validly) == address(0)) {
            revert ValidlyFactory__createPool_failedDeployment();
        }

        ISovereignPool(pool).setALM(address(validly));
    }

    /**
     * @notice Sets the pool manager fees for a given pool
     * @dev This function is used to set the pool manager fees for a given pool
     * @param _pool The address of the pool to set the pool manager fees for
     * @param _feeBips The fee percentage for the pool manager
     * @custom:error ValidlyFactory__setPoolManagerFees_unauthorized Thrown if the caller is not the protocol manager
     */
    function setPoolManagerFeeBips(address _pool, uint256 _feeBips) external {
        if (msg.sender != protocolFactory.protocolManager()) {
            revert ValidlyFactory__setPoolManagerFees_unauthorized();
        }

        ISovereignPool(_pool).setPoolManagerFeeBips(_feeBips);
    }

    /**
     * @notice Claims the pool manager fees for a given pool
     * @dev This function is used to claim the pool manager fees for a given pool
     * @param _pool The address of the pool to claim the pool manager fees for
     */
    function claimFees(address _pool) external {
        // It marks all fees as protocol fees to be used by gauge
        ISovereignPool(_pool).claimPoolManagerFees(10_000, 10_000);
    }

    /**
     *  INTERNAL FUNCTIONS
     */
    function _poolKey(address token0, address token1, bool isStable) internal pure returns (bytes32 key) {
        key = keccak256(abi.encode(token0, token1, isStable));
    }
}
