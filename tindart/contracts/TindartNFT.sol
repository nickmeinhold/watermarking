// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TindartNFT
 * @notice NFT contract for Tindart AI art marketplace with watermark verification
 * @dev ERC721 with license types, marketplace, and royalties
 */
contract TindartNFT is ERC721, ERC721URIStorage, ERC721Royalty, Ownable, ReentrancyGuard {

    // ============ Enums ============

    enum LicenseType {
        Display,      // Personal display only
        Commercial,   // Commercial usage rights
        Transfer      // Full copyright transfer
    }

    // ============ Structs ============

    struct TokenData {
        address creator;
        LicenseType licenseType;
        bytes32 imageHash;        // SHA-256 of original image
        bytes32 licenseHash;      // SHA-256 of signed license document
        uint256 mintedAt;
        string encryptedBlobUri;  // IPFS URI of encrypted original
    }

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    // ============ State Variables ============

    uint256 private _nextTokenId;
    uint96 public constant ROYALTY_BPS = 250; // 2.5% royalty to creator
    uint96 public constant PLATFORM_FEE_BPS = 250; // 2.5% platform fee

    mapping(uint256 => TokenData) public tokenData;
    mapping(uint256 => Listing) public listings;
    mapping(bytes32 => bool) public imageHashExists; // Prevent duplicate mints

    address public platformWallet;

    // ============ Events ============

    event Minted(
        uint256 indexed tokenId,
        address indexed creator,
        LicenseType licenseType,
        bytes32 imageHash
    );

    event Listed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event Delisted(
        uint256 indexed tokenId,
        address indexed seller
    );

    event Sold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    // ============ Errors ============

    error ImageAlreadyRegistered();
    error NotTokenOwner();
    error NotListed();
    error AlreadyListed();
    error InsufficientPayment();
    error CannotBuyOwnToken();
    error TransferFailed();
    error InvalidPrice();

    // ============ Constructor ============

    constructor(address _platformWallet)
        ERC721("Tindart", "TIND")
        Ownable(msg.sender)
    {
        platformWallet = _platformWallet;
    }

    // ============ Minting ============

    /**
     * @notice Mint a new NFT with watermarked artwork
     * @param to Address to mint to
     * @param uri Token metadata URI (IPFS)
     * @param licenseType Type of license (Display, Commercial, Transfer)
     * @param imageHash SHA-256 hash of original image
     * @param licenseHash SHA-256 hash of signed license document
     * @param encryptedBlobUri IPFS URI of encrypted original image
     */
    function mint(
        address to,
        string memory uri,
        LicenseType licenseType,
        bytes32 imageHash,
        bytes32 licenseHash,
        string memory encryptedBlobUri
    ) external returns (uint256) {
        // Prevent duplicate images
        if (imageHashExists[imageHash]) {
            revert ImageAlreadyRegistered();
        }

        uint256 tokenId = _nextTokenId++;

        // Store token data
        tokenData[tokenId] = TokenData({
            creator: to,
            licenseType: licenseType,
            imageHash: imageHash,
            licenseHash: licenseHash,
            mintedAt: block.timestamp,
            encryptedBlobUri: encryptedBlobUri
        });

        // Mark image hash as used
        imageHashExists[imageHash] = true;

        // Mint the token
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        // Set royalty for creator (2.5%)
        _setTokenRoyalty(tokenId, to, ROYALTY_BPS);

        emit Minted(tokenId, to, licenseType, imageHash);

        return tokenId;
    }

    // ============ Marketplace ============

    /**
     * @notice List a token for sale
     * @param tokenId Token to list
     * @param price Price in wei
     */
    function list(uint256 tokenId, uint256 price) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner();
        }
        if (listings[tokenId].active) {
            revert AlreadyListed();
        }
        if (price == 0) {
            revert InvalidPrice();
        }

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit Listed(tokenId, msg.sender, price);
    }

    /**
     * @notice Remove a listing
     * @param tokenId Token to delist
     */
    function delist(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];

        if (!listing.active) {
            revert NotListed();
        }
        if (listing.seller != msg.sender) {
            revert NotTokenOwner();
        }

        listing.active = false;

        emit Delisted(tokenId, msg.sender);
    }

    /**
     * @notice Buy a listed token
     * @param tokenId Token to buy
     */
    function buy(uint256 tokenId) external payable nonReentrant {
        Listing storage listing = listings[tokenId];

        if (!listing.active) {
            revert NotListed();
        }
        if (msg.value < listing.price) {
            revert InsufficientPayment();
        }
        if (msg.sender == listing.seller) {
            revert CannotBuyOwnToken();
        }

        address seller = listing.seller;
        uint256 price = listing.price;

        // Clear listing before transfers (reentrancy protection)
        listing.active = false;

        // Calculate fees
        uint256 platformFee = (price * PLATFORM_FEE_BPS) / 10000;
        uint256 royaltyAmount = 0;
        address royaltyRecipient;

        // Get royalty info
        (royaltyRecipient, royaltyAmount) = royaltyInfo(tokenId, price);

        // Don't pay royalty to seller (they're already getting the sale)
        if (royaltyRecipient == seller) {
            royaltyAmount = 0;
        }

        uint256 sellerProceeds = price - platformFee - royaltyAmount;

        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);

        // Pay platform
        (bool platformSuccess, ) = platformWallet.call{value: platformFee}("");
        if (!platformSuccess) revert TransferFailed();

        // Pay royalty to creator (if applicable)
        if (royaltyAmount > 0) {
            (bool royaltySuccess, ) = royaltyRecipient.call{value: royaltyAmount}("");
            if (!royaltySuccess) revert TransferFailed();
        }

        // Pay seller
        (bool sellerSuccess, ) = seller.call{value: sellerProceeds}("");
        if (!sellerSuccess) revert TransferFailed();

        // Refund excess payment
        if (msg.value > price) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - price}("");
            if (!refundSuccess) revert TransferFailed();
        }

        emit Sold(tokenId, seller, msg.sender, price);
    }

    // ============ View Functions ============

    /**
     * @notice Get full token data
     */
    function getTokenData(uint256 tokenId) external view returns (
        address creator,
        address currentOwner,
        LicenseType licenseType,
        bytes32 imageHash,
        bytes32 licenseHash,
        uint256 mintedAt,
        string memory encryptedBlobUri,
        string memory uri
    ) {
        TokenData memory data = tokenData[tokenId];
        return (
            data.creator,
            ownerOf(tokenId),
            data.licenseType,
            data.imageHash,
            data.licenseHash,
            data.mintedAt,
            data.encryptedBlobUri,
            tokenURI(tokenId)
        );
    }

    /**
     * @notice Get listing info
     */
    function getListing(uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        bool active
    ) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price, listing.active);
    }

    /**
     * @notice Check if an image hash is already registered
     */
    function isImageRegistered(bytes32 imageHash) external view returns (bool) {
        return imageHashExists[imageHash];
    }

    /**
     * @notice Get total supply
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update platform wallet
     */
    function setPlatformWallet(address _platformWallet) external onlyOwner {
        platformWallet = _platformWallet;
    }

    // ============ Overrides ============

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);

        // Auto-delist when transferred outside marketplace
        if (listings[tokenId].active && from != address(0)) {
            listings[tokenId].active = false;
            emit Delisted(tokenId, from);
        }

        return from;
    }
}
