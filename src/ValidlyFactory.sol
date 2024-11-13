// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProtocolFactory} from "@valantis-core/protocol-factory/interfaces/IProtocolFactory.sol";
import {SovereignPoolConstructorArgs} from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";

import {Validly} from "./Validly.sol";
import {IValidly} from "./interfaces/IValidly.sol";
import {IValidlyFactory} from "./interfaces/IValidlyFactory.sol";

contract ValidlyFactory is IValidlyFactory {
    using SafeERC20 for IERC20;

    /**
     *  ERRORS
     */
    error ValidlyFactory__onlyProtocolManager();
    error ValidlyFactory__claimTokens_invalidRecipient();
    error ValidlyFactory__claimTokens_invalidToken();
    error ValidlyFactory__constructor_invalidFeeBips();
    error ValidlyFactory__createPair_alreadyDeployed();
    error ValidlyFactory__createPair_invalidFeeBips();
    error ValidlyFactory__setPoolManagerFees_unauthorized();
    error ValidlyFactory__setDefaultPoolManagerFees_unauthorized();
    error ValidlyFactory__setDefaultPoolManagerFeeBips_excessivePoolManagerFee();
    error ValidlyFactory___setFeeTierAsEnabled_invalidFeeBips();

    /**
     *  CONSTANTS
     */

    /**
        @notice Maximum swap fee is 50% of input amount. 
        @dev See docs for a more detailed explanation about how swap fees are applied.
     */
    uint256 private constant _MAX_SWAP_FEE_BIPS = 10_000;

    /**
        @notice Factor of one or 100% representation in Basis points
     */
    uint256 private constant _FACTOR_ONE = 10_000;

    /**
        @notice `poolManager` can collect up to 50% of swap fees.
     */
    uint256 private constant _MAX_POOL_MANAGER_FEE_BIPS = 5_000;

    /**
     *  IMMUTABLES
     */

    /**
     * @notice The protocol factory contract used for deploying pools.
     * @dev This is set in the constructor and cannot be changed.
     */
    IProtocolFactory public immutable protocolFactory;

    /**
     *  STORAGE
     */

    /**
     * @notice Mapping from fee hundreth of basis points to an enabled flag.
     */
    mapping(uint256 fee => bool enabled) public feeTiers;

    /**
     * @notice Mapping from pool keys to pool addresses.
     */
    mapping(bytes32 key => address pool) public pools;

    /**
     * @notice Default basis points value for pool protocol fees.
     */
    uint256 public defaultPoolManagerFeeBips;

    /**
     *  CONSTRUCTOR
     */
    constructor(address _protocolFactory, uint256[] memory _feeTiers, uint256 _defaultPoolManagerFeeBips) {
        protocolFactory = IProtocolFactory(_protocolFactory);

        for (uint256 i; i < _feeTiers.length;) {
            _setFeeTierAsEnabled(_feeTiers[i]);

            unchecked {
                i++;
            }
        }

        _setDefaultPoolManagerFeeBips(_defaultPoolManagerFeeBips);
    }

    /**
     *
     *  MODIFIERS
     *
     */
    modifier onlyProtocolManager() {
        if (msg.sender != protocolFactory.protocolManager()) {
            revert ValidlyFactory__onlyProtocolManager();
        }
        _;
    }

    /**
     *  EXTERNAL FUNCTIONS
     */

    /**
     * @notice Deploys a new Validly pool for a given token pair.
     * @dev Tokens are sorted internally to ensure consistent pool keys.
     * @param _token0 The address of the first token in the pair.
     * @param _token1 The address of the second token in the pair.
     * @param _isStable Boolean indicating if the pool should be stable or volatile.
     * @param _feeBips The number of basis points to be used for the swap fee.
     * @custom:error ValidlyFactory__createPair_alreadyDeployed Thrown if a pool for the given token pair and stability type already exists.
     * @custom:error ValidlyFactory__createPair_failedDeployment Thrown if the Validly contract deployment fails.
     * @custom:error ValidlyFactory__createPair_invalidFeeBips Thrown if the feeBips is not between 0 and 10000.
     */
    function createPair(address _token0, address _token1, bool _isStable, uint16 _feeBips) external returns (address) {
        (_token0, _token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

        bytes32 poolKey = _poolKey(_token0, _token1, _isStable, _feeBips);

        if (pools[poolKey] != address(0)) {
            revert ValidlyFactory__createPair_alreadyDeployed();
        }

        if (!feeTiers[_feeBips]) {
            revert ValidlyFactory__createPair_invalidFeeBips();
        }

        SovereignPoolConstructorArgs memory args = SovereignPoolConstructorArgs({
            token0: _token0,
            token1: _token1,
            protocolFactory: address(protocolFactory),
            poolManager: address(this),
            sovereignVault: address(0),
            verifierModule: address(0),
            isToken0Rebase: false,
            isToken1Rebase: false,
            token0AbsErrorTolerance: 0,
            token1AbsErrorTolerance: 0,
            defaultSwapFeeBips: _feeBips
        });

        address pool = protocolFactory.deploySovereignPool(args);

        ISovereignPool(pool).setPoolManagerFeeBips(defaultPoolManagerFeeBips);

        Validly validly = new Validly{salt: poolKey}(pool, _isStable);

        ISovereignPool(pool).setALM(address(validly));

        pools[poolKey] = pool;

        emit PoolCreated(pool, _token0, _token1, _isStable, _feeBips);

        return address(validly);
    }

    /**
     * @notice Creates a new Validly pool, mostly for rebase tokens, which is not indexed in pools mapping.
     * @dev This function is used to create a pool given the SovereignPool constructor arguments.
     * @param _args The constructor arguments for the SovereignPool.
     * @param _isStable Boolean indicating if the pool should be stable or volatile.
     * @custom:error ValidlyFactory__createPool_failedDeployment Thrown if the Validly contract deployment fails.
     */
    function createPool(SovereignPoolConstructorArgs memory _args, bool _isStable) external returns (address validly) {
        _args.poolManager = address(this);
        // This factory does not support Sovereign Pools with Verifier Modules
        _args.verifierModule = address(0);

        address pool = protocolFactory.deploySovereignPool(_args);

        ISovereignPool(pool).setPoolManagerFeeBips(defaultPoolManagerFeeBips);

        validly = address(new Validly(pool, _isStable));

        ISovereignPool(pool).setALM(address(validly));

        emit PoolCreated(pool, _args.token0, _args.token1, _isStable, uint16(_args.defaultSwapFeeBips));
    }

    /**
     * @notice Sets the pool manager fees for a given pool.
     * @dev This function is used to set the pool manager fees for a given pool.
     * @param _pool The address of the pool to set the pool manager fees for.
     * @param _feeBips The fee percentage for the pool manager.
     * @custom:error ValidlyFactory__setPoolManagerFees_unauthorized Thrown if the caller is not the protocol manager.
     */
    function setPoolManagerFeeBips(address _pool, uint256 _feeBips) external onlyProtocolManager {
        ISovereignPool(_pool).setPoolManagerFeeBips(_feeBips);

        emit PoolManagerFeeBipsSet(_pool, _feeBips);
    }

    /**
     * @notice Sets the default pool manager fees for newly created pools.
     * @dev This function is used to set the default pool manager fees for newly created pools.
     * @param _feeBips The fee percentage for the pool manager.
     * @custom:error ValidlyFactory__setDefaultPoolManagerFees_unauthorized Thrown if the caller is not the protocol manager.
     */
    function setDefaultPoolManagerFeeBips(uint256 _feeBips) external onlyProtocolManager {
        _setDefaultPoolManagerFeeBips(_feeBips);
    }

    /**
     * @notice Enables a fee tier to be usable for pool creation.
     * @dev This function is used to set as fee tier as enabled for pool creation.
     * @param _feeBips The fee percentage to enable as a swap fee.
     * @custom:error ValidlyFactory__setDefaultPoolManagerFees_unauthorized Thrown if the caller is not the protocol manager.
     */
    function setFeeTierAsEnabled(uint256 _feeBips) external onlyProtocolManager {
        _setFeeTierAsEnabled(_feeBips);
    }

    /**
     * @notice Claims rebase token fees accumulated in this contract.
     * @dev By design of Sovereign Pools, manager fees for rebase tokens
     *      get transferred on every swap to its manager (this contract).
     * @param _token The address of the token to claim.
     * @param _recipient The address of the recipient.
     */
    function claimTokens(address _token, address _recipient) external onlyProtocolManager {
        if (_token == address(0)) {
            revert ValidlyFactory__claimTokens_invalidToken();
        }
        if (_recipient == address(0)) {
            revert ValidlyFactory__claimTokens_invalidRecipient();
        }

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));

        if (balance > 0) {
            token.safeTransfer(_recipient, balance);

            emit TokenClaimed(_token, _recipient, balance);
        }
    }

    /**
     * @notice Claims the pool manager fees for a given pool.
     * @dev This function is used to claim the pool manager fees for a given pool.
     * @param _pool The address of the pool to claim the pool manager fees for.
     */
    function claimFees(address _pool) external {
        // It marks all fees as protocol fees to be used by gauge
        ISovereignPool(_pool).claimPoolManagerFees(10_000, 10_000);

        emit FeesClaimed(_pool);
    }

    /**
     * @notice Gets the Sovereign Pool address for a given pair.
     * @dev This function is used to return the Validly and SovereignPool addresses for a given pair.
     * @return validlyPool The address of the Validly Pool of the pair to deposit/withdraw liquidity.
     * @return sovereignPool The address of the Sovereign Pool of the pair to swap liquidity.
     */
    function getPoolAddresses(address token0, address token1, bool isStable, uint16 fee)
        external
        view
        returns (address validlyPool, address sovereignPool)
    {
        validlyPool = pools[_poolKey(token0, token1, isStable, fee)];
        sovereignPool = address(IValidly(validlyPool).pool());
    }

    /**
     *  PRIVATE FUNCTIONS
     */
    function _setDefaultPoolManagerFeeBips(uint256 _feeBips) private {
        if (_feeBips > _MAX_POOL_MANAGER_FEE_BIPS) {
            revert ValidlyFactory__setDefaultPoolManagerFeeBips_excessivePoolManagerFee();
        }
        
        defaultPoolManagerFeeBips = _feeBips;

        emit DefaultPoolManagerFeeBipsSet(_feeBips);
    }

    function _setFeeTierAsEnabled(uint256 _feeBips) private {
        if (_feeBips > _MAX_SWAP_FEE_BIPS) {
            revert ValidlyFactory___setFeeTierAsEnabled_invalidFeeBips();
        }
        
        feeTiers[_feeBips] = true;

        emit FeeTierEnabled(_feeBips);
    }

    function _poolKey(address token0, address token1, bool isStable, uint16 feeBips) private pure returns (bytes32 key) {
        key = keccak256(abi.encode(token0, token1, isStable, feeBips));
    }
}
