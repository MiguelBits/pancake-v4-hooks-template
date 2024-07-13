// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@pancakeswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./pool-cl/CLBaseHook.sol";

contract WaffleHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {}
    
    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterAddLiquidityReturnsDelta: false,
                afterRemoveLiquidityReturnsDelta: false
            })
        );
    }
/*
    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata hookData
    ) external virtual returns (bytes4) {
        (uint256 leverage, bool isLong) = abi.decode(hookData, (uint256, bool));
        //require(1 ether < leverage <= 2 ether || leverage == 0, "LEVERAGE_NOT_SUPPORTED");
        
        if(leverage > 0) {
            PoolId poolId = key.toId();
            //lendingManager.lend(poolId, leverage, isLong);
        }
        else{
            return this.beforeAddLiquidity.selector;
        }
    }

    
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta){
        //if msg.sender is the lending manager, then remove liquidity, then add again, but only the not borrowed amount

    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata, bytes calldata hookData)
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // check if user is asking for leverage
        (uint256 leverage, uint256 fee) = abi.decode(hookData, (uint24, uint24));
    }
    */
}
