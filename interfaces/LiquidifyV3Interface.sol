// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface LiquidifyV3FactoryInterface {
    function protocolFeeReceiver() external view returns (address);
    function managerAddress() external view returns (address);
    function storageFee(address liquidifyContract, uint256 quantity) external view returns (uint256);
}