// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../ERC20/ERC20.sol";
import "../Admin/AdminControl.sol";
import "../interfaces/UniswapV2Interface.sol";

contract LiquidifyStandard is ERC20, AdminControl {
    IUniswapV2Router public swapRouter = IUniswapV2Router(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    uint256 constant protocolFee = 25;
    uint256 constant feeBase = 10000;

    constructor(
        address _factoryContract,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) AdminControl(_factoryContract) {}

    function _transfer(address from, address to, uint256 value) internal override {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 transferAmount = value;
        uint256 totalFeeAmount = 0;
        
        address protocolFeeReceiver = factory.protocolFeeReceiver();

        if (creatorSellFee != 0 && liquidityPools[to] && from != protocolFeeReceiver) {
            uint256 totalFeeRate = protocolFee + creatorSellFee;
            totalFeeAmount = (value * totalFeeRate) / feeBase;

            transferAmount -= totalFeeAmount;
            _update(from, protocolFeeReceiver, totalFeeAmount);
        }
        
        _update(from, to, transferAmount);
    }
}