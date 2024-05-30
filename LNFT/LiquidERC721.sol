// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Liquidify V3 LiquidERC721 

import "../Standard/LiquidifyStandard.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract LiquidERC721 is LiquidifyStandard {
    address public immutable nftContractAddress;
    uint256 public immutable tokensPerNft;

    mapping(uint256 => uint256[]) public storedNfts;
    mapping(uint256 => uint256) public tiers;
    uint256[] public tiersList;
    
    bool public pairEnabled = false;

    // Events
    event WrapERC721(uint256[] tokenIds, uint256 tokensMinted);
    event UnwrapERC721(uint256 quantity, uint256 tokenId);
    event EnablePair();

    constructor(
        address _factoryContract,
        string memory tokenName,
        string memory tokenSymbol,
        address _nftContractAddress,
        uint256 _tokensPerNft,
        uint256 _creatorSellFee,
        address _owner
    ) LiquidifyStandard(_factoryContract, tokenName, tokenSymbol) {
        require(_tokensPerNft >= 1, "Tokens per NFT must be greater than 0");
        require(_creatorSellFee <= 500, "Maximum creator sell fee is 5%");

        nftContractAddress = _nftContractAddress;
        tokensPerNft = _tokensPerNft * 10 ** 18;

        creatorSellFee = _creatorSellFee;
        owner = _owner;
        feeReceiver = _owner;

        address swapPair = IUniswapV2Factory(swapRouter.factory()).createPair(address(this), swapRouter.WETH());
        liquidityPools[swapPair] = true;

        tiersList.push(tokensPerNft);
    }

    // Wrap & Unwrap
    function wrapERC721(uint256[] memory _tokenIds) external nonReentrant payable {
        require(pairEnabled, "Pair not been enabled");
        
        uint256 storageFee = factory.storageFee(address(this), _tokenIds.length);
        require(msg.value >= storageFee, "Insufficient storage fee");

        uint256 totalTokens = 0;
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];

            IERC721(nftContractAddress).transferFrom(
                msg.sender,
                address(this),
                _tokenId
            );

            uint256 tokens = tokensPerNft;
            if (tiers[_tokenId] != 0) {
                tokens = tiers[_tokenId];
            }

            storedNfts[tokens].push(_tokenId);
            totalTokens += tokens;
        }

        address protocolFeeReceiver = factory.protocolFeeReceiver();
        (bool success, ) = payable(protocolFeeReceiver).call{value: msg.value}("");
        require(success, "Transfer to protocol failed");

        _mint(msg.sender, totalTokens);

        emit WrapERC721(_tokenIds, totalTokens);
    }

    function unwrapERC721(uint256 amount) external nonReentrant payable {
        require(pairEnabled, "Pair not enabled");
        require(storedNfts[amount].length != 0, "No NFTs to unwrap in this tier");
        
        uint256 storageFee = factory.storageFee(address(this), 1);
        require(msg.value >= storageFee, "Insufficient storage fee");

        _burn(msg.sender, amount);

        uint256 tokenId = storedNfts[amount][storedNfts[amount].length - 1];
        storedNfts[amount].pop();

        address protocolFeeReceiver = factory.protocolFeeReceiver();
        (bool success, ) = payable(protocolFeeReceiver).call{value: msg.value}("");
        require(success, "Transfer to protocol failed");

        IERC721(nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit UnwrapERC721(amount, tokenId);
    }
    
    // Owner
    function enablePair() external onlyOwner {
        require(!pairEnabled, "Pair already enabled");
        pairEnabled = true;
        emit EnablePair();
    }

    function setTiers(uint256[] memory tokenIds, uint256[] memory newTiers) external onlyOwner {
        require(tiersList.length <= 15, "Maximum tier limit reached");
        require(!pairEnabled, "Pair already enabled");
        require(tokenIds.length == newTiers.length, "Mismatch in arrays");

        for (uint i = 0; i < tokenIds.length; i++) {
            uint256 newTier = newTiers[i] * 10 ** 18;
            require(newTier >= tokensPerNft, "New tier has to be greater than base tier");

            tiers[tokenIds[i]] = newTier;

            if (!isTierPresent(newTier)) {
                tiersList.push(newTier);
            }
        }
    }

    // Reads
    function getQtyForTier(uint256 amount) external view returns (uint256) {
        return storedNfts[amount * 10 ** 18].length;
    }

    function getTiersCount() external view returns (uint256) {
        return tiersList.length;
    }

    function isTierPresent(uint256 _tier) internal view returns (bool) {
        for (uint i = 0; i < tiersList.length; i++) {
            if (tiersList[i] == _tier) {
                return true;
            }
        }

        return false;
    }
}