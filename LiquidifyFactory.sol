// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Liquidify V3 Factory

import {LiquidERC721} from "./LNFT/LiquidERC721.sol";
import {LiquidERC1155} from "./LNFT/LiquidERC1155.sol";

contract LiquidifyV3Factory {
    address public foundationAddress;
    address public protocolFeeReceiver;
    address public managerAddress;

    uint256 public baseStorageFee = 0.0002 ether;
    uint256 public baseMaxStorageFeePerTx = 0.005 ether;

    mapping(address => uint256) public customStorageFee;
    mapping(address => uint256) public customMaxStorageFeePerTx;
    
    mapping(address => bool) public createdContracts;

    event LiquidERC721Created(address indexed newContractAddress, string tokenName, string tokenSymbol, address nftContractAddress, uint256 tokensPerNft, uint256 creatorSellFee, address lnftPairCreator);
    event LiquidERC1155Created(address indexed newContractAddress, string tokenName, string tokenSymbol, address nftContractAddress, uint256 creatorSellFee, address lnftPairCreator);

    constructor(address _foundationAddress, address _managerAddress, address _protocolFeeReceiver) {
        require(_foundationAddress != address(0), "Foundation address cannot be zero");
        
        foundationAddress = _foundationAddress;
        managerAddress = _managerAddress;
        protocolFeeReceiver = _protocolFeeReceiver;
    }

    function createLiquidERC721(
        string memory tokenName,
        string memory tokenSymbol,
        address nftContractAddress,
        uint256 tokensPerNft,
        uint256 creatorSellFee
    ) external returns (address) {
        require(nftContractAddress != address(0), "NFT contract address cannot be zero");
        require(tokensPerNft >= 1, "Tokens per NFT must be greater than 0");

        LiquidERC721 newContract = new LiquidERC721(
            address(this),
            tokenName,
            tokenSymbol,
            nftContractAddress,
            tokensPerNft,
            creatorSellFee,
            msg.sender
        );

        createdContracts[address(newContract)] = true;

        emit LiquidERC721Created(address(newContract), tokenName, tokenSymbol, nftContractAddress, tokensPerNft, creatorSellFee, msg.sender);

        return address(newContract);
    }

    function createLiquidERC1155(
        string memory tokenName,
        string memory tokenSymbol,
        address nftContractAddress,
        uint256 creatorSellFee
    ) external returns (address) {
        require(nftContractAddress != address(0), "NFT contract address cannot be zero");

        LiquidERC1155 newContract = new LiquidERC1155(
            address(this),
            tokenName,
            tokenSymbol,
            nftContractAddress,
            creatorSellFee,
            msg.sender
        );

        createdContracts[address(newContract)] = true;

        emit LiquidERC1155Created(address(newContract), tokenName, tokenSymbol, nftContractAddress, creatorSellFee, msg.sender);

        return address(newContract);
    }

    function changeFoundationAddress(address _newFoundationAddress) external {
        require(msg.sender == foundationAddress, "Only Liquidify Foundation");
        require(_newFoundationAddress != address(0), "New foundation address cannot be 0");

        foundationAddress = _newFoundationAddress;
    }

    function changeManagerAddress(address _newManager) external {
        require(msg.sender == foundationAddress, "Only Liquidify Foundation");
        require(_newManager != address(0), "New Manager cannot be 0");

        managerAddress = _newManager;
    }

    function changeProtocolFeeReceiver(address _newProtocolFeeReceiver) external {
        require(msg.sender == foundationAddress, "Only Liquidify Foundation");
        require(_newProtocolFeeReceiver != address(0), "New Fee Receiver cannot be 0");

        protocolFeeReceiver = _newProtocolFeeReceiver;
    }

    // Storage fees
    function changeBaseStorageFee(uint256 _newBaseStorageFee) external {
        require(msg.sender == foundationAddress, "Only the Liquidify Foundation Multi-sig can call this");
        require(_newBaseStorageFee != 0, "New storage fee cannot be 0");

        baseStorageFee = _newBaseStorageFee;
    }

    function changeBaseMaxStorageFeePerTx(uint256 _newBaseMaxStorageFeePerTx) external {
        require(msg.sender == foundationAddress, "Only the Liquidify Foundation Multi-sig can call this");
        require(_newBaseMaxStorageFeePerTx != 0, "New storage fee cannot be 0");

        baseMaxStorageFeePerTx = _newBaseMaxStorageFeePerTx;
    }

    function setCustomBaseStorageFee(address liquidifyContract, uint256 _newFee) external {
        require(msg.sender == managerAddress, "Only the Liquidify Management can call this");

        customStorageFee[liquidifyContract] = _newFee;
    }

    function setCustomBaseMaxStorageFeePerTx(address liquidifyContract, uint256 _newFee) external {
        require(msg.sender == managerAddress, "Only the Liquidify Management can call this");

        customMaxStorageFeePerTx[liquidifyContract] = _newFee;
    }

    // Reads
    function storageFee(address liquidifyContract, uint256 quantity) external view returns (uint256) {
        uint256 _storageFee = baseStorageFee;

        if (customStorageFee[liquidifyContract] != 0) {
            _storageFee = customStorageFee[liquidifyContract];
        }

        uint256 totalStorageFee = _storageFee * quantity;
        uint256 _maxStorageFeePerTx = maxStorageFeePerTx(liquidifyContract);

        if (totalStorageFee > _maxStorageFeePerTx) {
            totalStorageFee = _maxStorageFeePerTx;
        }

        return totalStorageFee;
    }

    function maxStorageFeePerTx(address liquidifyContract) public view returns (uint256) {
        uint256 _maxStorageFeePerTx = baseMaxStorageFeePerTx;

        if (customMaxStorageFeePerTx[liquidifyContract] != 0) {
            _maxStorageFeePerTx = customMaxStorageFeePerTx[liquidifyContract];
        }

        return _maxStorageFeePerTx;
    }

    function isContractCreated(address _contract) external view returns (bool) {
        return createdContracts[_contract];
    }
}