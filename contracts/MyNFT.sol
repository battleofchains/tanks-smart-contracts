// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyNFT is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    address payable public _contractOwner;

    mapping (uint256 => uint256) public price;
    mapping (uint256 => bool) public listedMap;
    mapping(uint256 => string) private _tokenURIs;

    event Purchase(address indexed previousOwner, address indexed newOwner, uint256 price, uint256 nftID, string uri);

    event Minted(address indexed minter, uint256 price, uint256 nftID, string uri);

    event PriceUpdate(address indexed owner, uint256 oldPrice, uint256 newPrice, uint256 nftID);

    event NftListStatus(address indexed owner, uint256 nftID, bool isListed);

    event Trade(uint256 nftID, uint256 sellerValue, uint256 commissionValue);

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _contractOwner = payable(msg.sender);
    }

    function decimals() public view virtual returns (uint8) {
        return 0;
    }

    function contractOwner() public view virtual returns (address) {
        return _contractOwner;
    }

    function mint(uint256 _tokenId, string memory _tokenURI, address _toAddress, uint256 _price) public returns (uint256) {
        price[_tokenId] = _price;
        listedMap[_tokenId] = true;

        _safeMint(_toAddress, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);

        emit Minted(_toAddress, _price, _tokenId, _tokenURI);

        return _tokenId;
    }

    function buyAndMint(uint256 _tokenId, string memory _tokenURI, uint256 _price) public returns (uint256) {
        require(!_exists(_tokenId), "Error, token already exists");

        address payable _buyer = payable(msg.sender);
        _contractOwner.transfer(_price);

        mint(_tokenId, _tokenURI, _buyer, _price);

        emit Purchase(address(0), _buyer, price[_tokenId], _tokenId, tokenURI(_tokenId));

        return _tokenId;
    }

    function buy(uint256 _id) external payable {
        _validate(_id);

        address _previousOwner = ownerOf(_id);
        address _newOwner = msg.sender;

        _trade(_id);

        emit Purchase(_previousOwner, _newOwner, price[_id], _id, tokenURI(_id));
    }

    function _validate(uint256 _id) internal {
        bool isItemListed = listedMap[_id];
        require(_exists(_id), "Error, wrong tokenId");
        require(isItemListed, "Item not listed currently");
        require(msg.value >= price[_id], "Error, the amount is lower");
        require(msg.sender != ownerOf(_id), "Can not buy what you own");
    }

    function _trade(uint256 _id) internal {
        address payable _buyer = payable(msg.sender);
        address payable _owner = payable(ownerOf(_id));

        _safeTransfer(_owner, _buyer, _id, "");

        // 1% commission cut
        uint256 _commissionValue = price[_id].div(100) ;
        uint256 _sellerValue = price[_id].sub(_commissionValue);

        _owner.transfer(_sellerValue);
        _contractOwner.transfer(_commissionValue);

        // If buyer sent more than price, we send them back their rest of funds
        if (msg.value > price[_id]) {
            _buyer.transfer(msg.value.sub(price[_id]));
        }

        listedMap[_id] = false;

        emit Trade(_id, _sellerValue, _commissionValue);
    }

    function updatePrice(uint256 _tokenId, uint256 _price) public returns (bool) {
        uint256 oldPrice = price[_tokenId];
        require(msg.sender == ownerOf(_tokenId), "Error, you are not the owner");
        price[_tokenId] = _price;

        emit PriceUpdate(msg.sender, oldPrice, _price, _tokenId);
        return true;
    }

    function updateListingStatus(uint256 _tokenId, bool shouldBeListed) public returns (bool) {
        require(msg.sender == ownerOf(_tokenId), "Error, you are not the owner");

        listedMap[_tokenId] = shouldBeListed;

        emit NftListStatus(msg.sender, _tokenId, shouldBeListed);

        return true;
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }
}
