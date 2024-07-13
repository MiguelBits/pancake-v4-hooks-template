// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultToken} from "@pancakeswap/v4-core/src/interfaces/IVaultToken.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from
    "@pancakeswap/v4-periphery/src/pool-cl/interfaces/INonfungiblePositionManager.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {CLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/CLPoolManager.sol";
import {FullMath} from "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {TickMath} from "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {LiquidityAmounts} from "@pancakeswap/v4-core/test/pool-cl/helpers/LiquidityAmounts.sol";
import {LiquidityERC20} from "./LiquidityERC20.sol";

contract WaffleLendingManager is LiquidityERC20 {
    using PoolIdLibrary for PoolKey;

    NonfungiblePositionManager pancake_periphery;
    CLPoolManager poolManager;

    mapping(PoolId poolId => uint256 vaultTokenId) public vaultTokenIds;

    constructor(address _poolManager, address _nfp) LiquidityERC20("WaffleLendingManager", "WLM") {
        pancake_periphery = NonfungiblePositionManager(payable(_nfp));
        poolManager = CLPoolManager(_poolManager);
    }

    function depositLiquidityForLending(PoolKey memory key, uint256 amount0, uint256 amount1) external {
        int24 bps = 10000;
        int24 _rangeCover = 20 * bps; //20%

        PoolId poolId = key.toId();
        (, int24 tick, ,) = poolManager.getSlot0(poolId);
        //get the tick spacing, + _rangeCover% or - _rangeCover%
        int24 upperBound = tick + (_rangeCover * tick) / bps;
        int24 lowerBound = tick - (_rangeCover * tick) / bps;

        uint128 liquidity = _addLiquidity(key, amount0, amount1, lowerBound, upperBound, tick);

        _mint(msg.sender, liquidity);
    }

    function removeLiquidityFromLending(PoolKey memory key, uint128 amount) external {
        PoolId poolId = key.toId();
        uint256 vaultTokenId = vaultTokenIds[poolId];

        //calculate how much liquidity the user is entitled to, similar to vault shares
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,
            ,
            
        ) = pancake_periphery.positions(vaultTokenId);

        //calculate liquidty to remove
        uint128 liquidityShares = liquidity * amount / totalSupply();

        pancake_periphery.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: vaultTokenId,
                liquidity: liquidityShares,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 1 days
            })
        );

        _burn(msg.sender, amount);
    }

    ///@param _amount the amount of liquidity to lend denominated in the pool's token1
    function lend(PoolId poolId, uint128 _amount, bool _long) external {
        require(vaultTokenIds[poolId] != 0, "Vault token does not exist");
        uint256 vaultTokenId = vaultTokenIds[poolId];

        (uint256 price, uint160 sqrtPriceX96) = getCurrentPrice(poolId);
            //L = sqrt(X*Y)
        uint128 withdrawAmount = calculateWithdrawableLiquidity(vaultTokenId, _amount, price, sqrtPriceX96);

        //decreaseLiquidity
        pancake_periphery.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: vaultTokenId,
            liquidity: withdrawAmount,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 1 days
        }));

        //add liquidity, but only the not borrowed amount
        //if long, ask collateral of token0, if short, ask collateral of token1
        //if long, lend token1, if short, lend token0

        if(_long){
            //lend token1
            
        }
        else{
            //lend token0
            
        }
    }

    function repayLoan(address _vaultToken, uint256 _amount) external {
        //deposit the lent amount in the liquidity pool + interest + fees
    }

    function liquidateLoan(address _vaultToken, uint256 _amount) external {
        //liquidate the loan, take the collateral, deposit the collateral in the liquidity pool
    }

    /////////////////////////////////
    function _addLiquidity(PoolKey memory key, uint256 amount0, uint256 amount1, int24 tickLower, int24 tickUpper, int24 _currentTick)
        internal returns(uint128 liquidity)
    {
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            poolKey: key,
            tickLower: tickLower,
            tickUpper: tickUpper,
            salt: bytes32(0),
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 1 days
        });
        
        //get pool id from key
        PoolId poolId = key.toId();
        if(vaultTokenIds[poolId] == 0) {
            //approve token0 and token1
            _approveCurrencies(key);

            (uint256 tokenId, uint128 _liquidity, , ) = pancake_periphery.mint(mintParams);
            vaultTokenIds[poolId] = tokenId;
            liquidity = _liquidity;
        }
        else {
            //if _currentTick is not between tickLower and tickUpper, then burn the existing vault token and mint a new one
            if(_currentTick < tickLower || _currentTick > tickUpper) {
                uint256 tokenId = vaultTokenIds[poolId];
                pancake_periphery.burn(tokenId);

                _approveCurrencies(key);

                (uint256 newTokenId, uint128 _liquidity, , ) = pancake_periphery.mint(mintParams);
                vaultTokenIds[poolId] = newTokenId;
                liquidity = _liquidity;
            }
            else{
                //add liquidity to the existing vault token
                uint256 tokenId = vaultTokenIds[poolId];
                (uint128 _liquidity, , ) = pancake_periphery.increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp + 1 days
                }));
                liquidity = _liquidity;
            }
        }
        
    }

    function _approveCurrencies(PoolKey memory key) internal {
        Currency currency0 = key.currency0;
        Currency currency1 = key.currency1;

        IVaultToken(Currency.unwrap(currency0)).approve(address(pancake_periphery), currency0, type(uint256).max);
        IVaultToken(Currency.unwrap(currency1)).approve(address(pancake_periphery), currency1, type(uint256).max);
    }
    
    //L = sqrt(X*Y)
    function getCurrentPrice(PoolId poolId) public view returns (uint256,uint160) {
        (uint160 sqrtPriceX96, , ,) = poolManager.getSlot0(poolId);
        
        uint256 priceX96 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 price = FullMath.mulDiv(priceX96, 1e18, 1 << 192);
        
        return (price,sqrtPriceX96);
    }

    function calculateWithdrawableLiquidity(
        uint256 tokenId,
        uint256 withdrawUSD,
        uint256 price,
        uint160 sqrtRatioX96
    ) public view returns (uint128) {
        (, , , , , , , uint128 liquidity, , , , ,) = pancake_periphery
            .positions(tokenId);

        // Fetch amounts of token0 (ETH) and token1 (USD) in the position
        (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(
            tokenId,
            liquidity,
            sqrtRatioX96
        );

        // Total value of the position in USD
        uint256 totalValue = (amount0 * price) / 1e18 + amount1;

        // Proportion of liquidity to withdraw
        uint256 proportion = (withdrawUSD * 1e18) / totalValue;

        // Calculate liquidity to withdraw
        uint128 liquidityToWithdraw = uint128((liquidity * proportion) / 1e18);

        return liquidityToWithdraw;
    }

    function _getAmountsForLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        // Get position details
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,
            ,
        ) = pancake_periphery.positions(tokenId);

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Calculate amounts of token0 and token1 for the given liquidity
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );
    }

    
}