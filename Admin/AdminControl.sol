// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../interfaces/LiquidifyV3Interface.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AdminControl is ReentrancyGuard {
    LiquidifyV3FactoryInterface public factory;

    address public owner;
    address public feeReceiver;
    
    uint256 public creatorSellFee = 0;

    mapping(address => bool) public liquidityPools;

    event SetLiquidityPool(address indexed lp, bool status);
    event ChangeOwner(address indexed newOwner);
    event ReduceSellFee(uint256 newFee);
    event SetFeeReceiver(address indexed newFeeReceiver);
    event RenounceOwnership();

    constructor(address _factoryAddress) {
        factory = LiquidifyV3FactoryInterface(_factoryAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner");
        _;
    }

    function setLiquidityPool(address _lp, bool _status) external {
        require(msg.sender == owner || msg.sender == factory.managerAddress(), "Only Owner or Liquidify Management");
        liquidityPools[_lp] = _status;

        emit SetLiquidityPool(_lp, _status);
    }

    function reduceSellFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= creatorSellFee, "Creator sell fee must be lower than current");
        creatorSellFee = _newFee;

        emit ReduceSellFee(_newFee);
    }

    function changeOwner(address _owner) external onlyOwner {
        require (_owner != address(0), "New owner cannot be 0");
        owner = _owner;

        emit ChangeOwner(_owner);
    }

    function renounceOwnership() external onlyOwner {
        require (owner != address(0), "Already renounced");
        owner = address(0);

        emit RenounceOwnership();
    }

    function setFeeReceiver(address _newFeeReceiver) external payable onlyOwner nonReentrant {
        require(msg.value >= 1, "min 1 wei");
        
        (bool success, ) = payable(_newFeeReceiver).call{value: msg.value}("");
        require(success, "Transfer failed");

        feeReceiver = _newFeeReceiver;

        emit SetFeeReceiver(_newFeeReceiver);
    }
}