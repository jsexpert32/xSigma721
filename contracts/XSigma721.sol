pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XSigma721 is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct TokenData {
        address payable creator;
        uint256 royalties;
    }
    mapping(uint256 => TokenData) public tokens;

    constructor() public ERC721("XSigma NFT", "XSIG") {}

    function getCreator(uint256 _tokenId) public view returns (address) {
        return tokens[_tokenId].creator;
    }

    function getRoyalties(uint256 _tokenId) public view returns (uint256) {
        return tokens[_tokenId].royalties;
    }

    function createItem(string memory tokenURI, uint256 _royalties)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        tokens[newItemId] = TokenData({ creator: msg.sender, royalties: _royalties});

        emit Approval(msg.sender, address(this), newItemId);

        return newItemId;
    }

    function extractBalance() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }
}
