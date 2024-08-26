// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ISovereignALM } from "@valantis-core/ALM/interfaces/ISovereignALM.sol";
import { ALMLiquidityQuoteInput, ALMLiquidityQuote } from "@valantis-core/ALM/structs/SovereignALMStructs.sol";
import { ISovereignPool } from "@valantis-core/pools/interfaces/ISovereignPool.sol";

/**
  @title Constant Product Liquidity Module.
  @dev UniswapV2 style constant product,
       implemented as a Valantis Sovereign Liquidity Module.
 */
contract Validly is ISovereignALM, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    /************************************************
    *  ERRORS
    ***********************************************/

    error Validly__deadlineExpired();
    error Validly__onlyPool();
    error Validly__priceOutOfRange();
    error Validly__constructor_customSovereignVaultNotAllowed();
    error Validly__constructor_invalidPool();
    error Validly__withdraw_AmountZero();
    error Validly__withdraw_insufficientToken0Withdrawn();
    error Validly__withdraw_insufficientToken1Withdrawn();
    error Validly__withdraw_zeroShares();
    error Validly__withdraw_invalidRecipient();
    error Validly__deposit_insufficientToken0Deposited();
    error Validly__deposit_insufficientToken1Deposited();
    error Validly__deposit_invalidRecipient();
    error Validly__deposit_zeroShares();
    error Validly__deposit_lessThanMinShares();

    /************************************************
    *  CONSTANTS
    ***********************************************/

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /************************************************
    *  IMMUTABLES
    ***********************************************/

    /**
        @dev SovereignPool is both the entry point contract for swaps (via `swap` function),
            and the contract in which token0 and token1 balances should be stored.
    */
    ISovereignPool public immutable pool;

    bool public immutable isStable;

    uint256 public immutable decimals0;
    uint256 public immutable decimals1;

    /************************************************
    *  CONSTRUCTOR
    ***********************************************/

    constructor(address _pool, bool _isStable) ERC20("Validly LP Token", "VAL-LP") {
        if (_pool == address(0)) revert Validly__constructor_invalidPool();

        pool = ISovereignPool(_pool);

        if (pool.sovereignVault() != _pool) revert Validly__constructor_customSovereignVaultNotAllowed();

        isStable = _isStable;

        decimals0 = 10 ** IERC20Metadata(pool.token0()).decimals();
        decimals1 = 10 ** IERC20Metadata(pool.token1()).decimals();
    }

    /************************************************
    *  MODIFIERS
    ***********************************************/

    modifier onlyPool() {
        if (msg.sender != address(pool)) {
            revert Validly__onlyPool();
        }
        _;
    }

    modifier ensureDeadline(uint256 deadline) {
        _checkDeadline(deadline);
        _;
    }


    /************************************************
    *  EXTERNAL FUNCTIONS
    ***********************************************/

    /**
        @notice Deposit liquidity into `POOL` and mint LP tokens.
        @param _amount0 Amount of token0 deposited.
        @param _amount1 Amount of token1 deposited.
        @param _minShares Minimum amount of shares to mint.
        @param _deadline Block timestamp after which this call reverts.
        @param _recipient Address to mint LP tokens for.
        @return shares Amount of shares minted.
    */
    function deposit(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _minShares,
        uint256 _deadline,
        address _recipient
    ) external ensureDeadline(_deadline) nonReentrant returns (uint256 shares) {

        if (_recipient == address(0)) revert Validly__deposit_invalidRecipient();

        uint256 amount0;
        uint256 amount1;
        uint256 totalSupplyCache = totalSupply();
        if (totalSupplyCache == 0) {
            // Minimum token amounts taken as amounts during first deposit
            amount0 = _amount0;
            amount1 = _amount1;

            _mint(address(1), MINIMUM_LIQUIDITY);

            // _shares param is ignored during first deposit
            shares = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            if(shares < _minShares) revert Validly__deposit_lessThanMinShares();
        } else {
            (uint256 reserve0, uint256 reserve1) = pool.getReserves();

            uint256 shares0 = Math.mulDiv(_amount0, totalSupplyCache, reserve0);
            uint256 shares1 = Math.mulDiv(_amount1, totalSupplyCache,reserve1);

            if(shares0 < _minShares && shares1 < _minShares) revert Validly__deposit_lessThanMinShares();
            
            
            // Normal deposits are made using `onDepositLiquidityCallback`
            if(shares0 < shares1){
                shares = shares0;
                amount1 = Math.mulDiv(reserve1, shares, totalSupplyCache, Math.Rounding.Ceil);
                amount0 = _amount0;
            }else{
                shares = shares1;
                amount0 = Math.mulDiv(reserve0, shares, totalSupplyCache, Math.Rounding.Ceil);
                amount1 = _amount1;
            }

            // @dev This is a sanity check to ensure that the amounts are not over the amounts specified
            // This can occure because of rounding errors in mulDiv ceiling
            if (amount0 > _amount0) revert Validly__deposit_insufficientToken0Deposited();
            if (amount1 > _amount1) revert Validly__deposit_insufficientToken1Deposited();
        }

        if (shares == 0) revert Validly__deposit_zeroShares();

        _mint(_recipient, shares);

        pool.depositLiquidity(
            amount0,
            amount1,
            msg.sender,
            "",
            abi.encode(msg.sender)
        );
    }

    /**
        @notice Withdraw liquidity from `POOL` and burn LP tokens.
        @param _shares Amount of LP tokens to burn.
        @param _amount0Min Minimum amount of token0 required for `_recipient`.
        @param _amount1Min Minimum amount of token1 required for `_recipient`.
        @param _deadline Block timestamp after which this call reverts.
        @param _recipient Address to receive token0 and token1 amounts.
        @return amount0 Amount of token0 withdrawn. WARNING: Potentially innacurate in case token0 is rebase.
        @return amount1 Amount of token1 withdrawn. WARNING: Potentially innacurate in case token1 is rebase.
    */
    function withdraw(
        uint256 _shares,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint256 _deadline,
        address _recipient
    ) external ensureDeadline(_deadline) nonReentrant returns (uint256 amount0, uint256 amount1) {

        if (_shares == 0) revert Validly__withdraw_zeroShares();

        if(_recipient == address(0)) revert Validly__withdraw_invalidRecipient();

        (uint256 reserve0, uint256 reserve1) = pool.getReserves();

        uint256 totalSupplyCache = totalSupply();
        amount0 = Math.mulDiv(reserve0, _shares, totalSupplyCache);
        amount1 = Math.mulDiv(reserve1, _shares, totalSupplyCache);

        if (amount0 == 0 || amount1 == 0) revert Validly__withdraw_AmountZero();

        // Slippage protection checks
        if (amount0 < _amount0Min) revert Validly__withdraw_insufficientToken0Withdrawn();
        if (amount1 < _amount1Min) revert Validly__withdraw_insufficientToken1Withdrawn();

        _burn(msg.sender, _shares);

        pool.withdrawLiquidity(amount0, amount1, msg.sender, _recipient, "");
    }

    /**
        @notice Callback to transfer tokens from user into `POOL` during deposits. 
    */
    function onDepositLiquidityCallback(
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external override onlyPool {
        address user = abi.decode(_data, (address));

        if (_amount0 > 0) {
            IERC20Metadata(pool.token0()).safeTransferFrom(user, msg.sender, _amount0);
        }

        if (_amount1 > 0) {
            IERC20Metadata(pool.token1()).safeTransferFrom(user, msg.sender, _amount1);
        }
    }

    /**
        @notice Swap callback from POOL.
        @param _poolInput Contains fundamental data about the swap. 
        @return quote Quote information that prices tokenIn and tokenOut.
    */
    function getLiquidityQuote(
        ALMLiquidityQuoteInput memory _poolInput,
        bytes calldata /*_externalContext*/,
        bytes calldata /*_verifierData*/
    ) external view override returns (ALMLiquidityQuote memory quote) {
        (uint256 reserve0, uint256 reserve1) = pool.getReserves();

        (uint256 reserveIn, uint256 reserveOut) = _poolInput.isZeroToOne ? (reserve0, reserve1) : (reserve1, reserve0);

        if(isStable){
            uint256 xy =  _k(reserve0, reserve1);
            reserveIn = _poolInput.isZeroToOne ? reserveIn * 1e18/decimals0 : reserveIn*1e18/decimals1;
            reserveOut = _poolInput.isZeroToOne ? reserveOut * 1e18/decimals1 : reserveOut*1e18/decimals0;
            uint256 amountIn = _poolInput.isZeroToOne ? _poolInput.amountInMinusFee * 1e18 / decimals0 : _poolInput.amountInMinusFee * 1e18 / decimals1;
            uint256 y = reserveOut - _get_y(amountIn+reserveIn, xy, reserveOut);
            quote.amountOut = y * (_poolInput.isZeroToOne ? decimals1 : decimals0) / 1e18;
        }else{
            quote.amountOut = (reserveOut * _poolInput.amountInMinusFee) / (reserveIn + _poolInput.amountInMinusFee);
        }

        quote.amountInFilled = _poolInput.amountInMinusFee;
    }

    // solhint-disable-next-line no-empty-blocks
    function onSwapCallback(bool /*_isZeroToOne*/, uint256 /*_amountIn*/, uint256 /*_amountOut*/) external override {}

    /************************************************
    *  PRIVATE FUNCTIONS
    ***********************************************/

    function _checkDeadline(uint256 _deadline) private view {
        if (block.timestamp > _deadline) {
        revert Validly__deadlineExpired();
        }
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return x0*(y*y/1e18*y/1e18)/1e18+(x0*x0/1e18*x0/1e18)*y/1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return 3*x0*(y*y/1e18)/1e18+(x0*x0/1e18*x0/1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = (xy - k)*1e18/_d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = (k - xy)*1e18/_d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        uint256 _x = x * 1e18 / decimals0;
        uint256 _y = y * 1e18 / decimals1;
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return _a * _b / 1e18;  // x3y+y3x >= k
    }
}