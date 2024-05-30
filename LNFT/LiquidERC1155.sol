// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Liquidify V3 LiquidERC1155

import "../Standard/LiquidifyStandard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
}

contract LiquidERC1155 is LiquidifyStandard, ERC1155Holder {
    address public immutable nftContractAddress;
    mapping(uint256 => uint256) public tokensPerNft;

    mapping(uint256 => uint256) public storedNfts;
    uint256[] public tiersList;

    // Events
    event WrapERC1155(uint256 tokenId, uint256 quantity);
    event UnwrapERC1155(uint256 tokenId, uint256 quantity);
    event EnablePair(uint256 tokenId, uint256 tokenAmount);

    constructor(
        address _factoryContract,
        string memory tokenName,
        string memory tokenSymbol,
        address _nftContractAddress,
        uint256 _creatorSellFee,
        address _owner
    ) LiquidifyStandard(_factoryContract, tokenName, tokenSymbol) {
        require(_creatorSellFee <= 500, "Maximum creator fee is 5%");

        nftContractAddress = _nftContractAddress;

        creatorSellFee = _creatorSellFee;
        owner = _owner;
        feeReceiver = _owner;

        address swapPair = IUniswapV2Factory(swapRouter.factory()).createPair(address(this), swapRouter.WETH());
        liquidityPools[swapPair] = true;
    }

    // Wrap & Unwrap
    function wrapERC1155(uint256 tokenId, uint256 quantity) external nonReentrant payable {
        require(tokensPerNft[tokenId] != 0, "Pair not enabled");

        uint256 storageFee = factory.storageFee(address(this), quantity);
        require(msg.value >= storageFee, "Insufficient storage fee");

        IERC1155(nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            quantity,
            ""
        );

        storedNfts[tokenId] += quantity;

        uint256 tokens = tokensPerNft[tokenId] * quantity;

        address protocolFeeReceiver = factory.protocolFeeReceiver();
        (bool success, ) = payable(protocolFeeReceiver).call{value: msg.value}("");
        require(success, "Transfer to protocol failed");

        _mint(msg.sender, tokens);

        emit WrapERC1155(tokenId, quantity);
    }

    function unwrapERC1155(uint256 tokenId, uint256 quantity) external nonReentrant payable {
        require(tokensPerNft[tokenId] != 0, "Pair not enabled");
        require(storedNfts[tokenId] >= quantity, "Insufficient NFTs to unwrap for this tokenId");
        
        uint256 storageFee = factory.storageFee(address(this), quantity);
        require(msg.value >= storageFee, "Insufficient storage fee");
    
        uint256 tokens = tokensPerNft[tokenId] * quantity;
        _burn(msg.sender, tokens);

        storedNfts[tokenId] -= quantity;

        address protocolFeeReceiver = factory.protocolFeeReceiver();
        
        (bool success, ) = payable(protocolFeeReceiver).call{value: msg.value}("");
        require(success, "Transfer to protocol failed");

        IERC1155(nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            quantity,
            ""
        );

        emit UnwrapERC1155(tokenId, quantity);
    }

    // Owner
    function enablePair(uint256 tokenId, uint256 tokenAmount) external onlyOwner {
        require(tokensPerNft[tokenId] == 0, "Pair already enabled");
        require(tokenAmount >= 1, "Tokens per NFT must be greater than 0");

        tokensPerNft[tokenId] = tokenAmount * 10 ** 18;
        tiersList.push(tokenId);

        emit EnablePair(tokenId, tokenAmount);
    }

    // Reads
    function getTiersCount() external view returns (uint256) {
        return tiersList.length;
    }
}