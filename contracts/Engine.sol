pragma solidity ^0.6.2;

import "./AddressUtils.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./XSigma721.sol";

contract Engine is Ownable {
    using SafeMath for uint256;
    using AddressUtils for address;

    event AuctionCreated(uint256 _index, address _creator, address _asset);
    event AuctionBid(uint256 _index, address _bidder, uint256 amount);
    event Claim(uint256 auctionIndex, address claimer);
    event ReturnBidFunds(uint256 _index, address _bidder, uint256 amount);

    event Royalties(address receiver, uint256 amount);
    event PaymentToOwner(
        address receiver,
        uint256 amount,
        uint256 paidByCustomer,
        uint256 commision,
        uint256 safetyCheckValue
    );

    enum Status {pending, active, finished}
    struct Auction {
        address assetAddress;
        uint256 assetId;
        address payable creator;
        uint256 startTime;
        uint256 duration;
        uint256 currentBidAmount;
        address payable currentBidOwner;
        uint256 bidCount;
    }
    Auction[] public auctions;

    uint256 commision = 500; // this is the commision that will charge the marketplace by default.

    struct Offer {
        address assetAddress;       // address of the token
        uint256 tokenId;            // the tokenId returned when calling "createItem"
        address payable creator;    // who creates the offer
        uint256 price;              // price of each token
        bool isOnSale;              // is on sale or not
        bool isAuction;             // is this offer is for an auction 
        uint256 idAuction;          // the id of the auction
    }
    mapping(uint256 => Offer) public offers;

    function createOffer(
        address _assetAddress,  // address of the token
        uint256 _tokenId,       // tokenId
        bool _isDirectSale,     // true if can be bought on a direct sale
        bool _isAuction,        // true if can be bought in an auction
        uint256 _price,         // price that if paid in a direct sale, transfers the NFT
        uint256 _startPrice,    // minimum price on the auction
        uint256 _startTime,     // time when the auction will start. Check the format with frontend
        uint256 _duration       // duration in seconds of the auction
    ) public {
        Offer memory offer =
            Offer({
                assetAddress: _assetAddress,
                tokenId: _tokenId,
                creator: msg.sender,
                price: _price,
                isOnSale: _isDirectSale,
                isAuction: _isAuction,
                idAuction: 0
            });
        if (_isAuction) {
            offer.idAuction = createAuction(
                _assetAddress,
                _tokenId,
                _startPrice,
                _startTime,
                _duration
            );
        }
        offers[_tokenId] = offer;
    }

    function getAuctionId(uint256 _tokenId) public view returns (uint256) {
        Offer memory offer = offers[_tokenId];
        return offer.idAuction;
    }

    function removeFromAuction(uint256 _tokenId) public
    {
        Offer memory offer = offers[_tokenId];
        require(msg.sender == offer.creator, "You are not the owner");
        Auction memory auction = auctions[offer.tokenId];
        require(auction.bidCount == 0, "Bids existing");
        offer.isAuction = false;
        offer.idAuction = 0;
        offers[_tokenId] = offer;
    }

    function removeFromSale(uint256 _tokenId) public
    {
        Offer memory offer = offers[_tokenId];
        require(msg.sender == offer.creator, "You are not the owner");
        offer.isOnSale = false;
        offers[_tokenId] = offer;
    }

    // Changes the default commision. Only the owner of the marketplace can do that
    function setCommision(uint256 _commision) public onlyOwner {
        commision = _commision;
    }

    function buy(uint256 _tokenId) external payable {
        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[_tokenId];
        require(offer.isOnSale == true, "NFT not in direct sale");
        uint256 price = offer.price;
        require(paidPrice >= price, "Price is not enough");

        emit Claim(_tokenId, buyer);
        XSigma721 asset = XSigma721(offer.assetAddress);
        asset.transferFrom(offer.creator, buyer, _tokenId);

   // now, pay the amount - commision - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(_tokenId));       

        uint256 commisionToPay = (paidPrice * commision) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT == offer.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay = (paidPrice * asset.getRoyalties(_tokenId)) / 10000;
            creatorNFT.transfer(royaltiesToPay);
            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay = paidPrice- commisionToPay - royaltiesToPay;       

        offer.creator.transfer(amountToPay);
        emit PaymentToOwner(
            offer.creator,
            amountToPay,
            paidPrice,
            commisionToPay,
            amountToPay + ((paidPrice * commision) / 10000)
        );

        // is there is an auction open, we have to give back the last bid amount to the last bidder
        if (offer.isAuction == true)
        {
            Auction memory auction = auctions[offer.idAuction];
            if (auction.currentBidAmount != 0) {
                // return funds to the previuos bidder
                auction.currentBidOwner.transfer(auction.currentBidAmount);
                emit ReturnBidFunds(
                    offer.idAuction,
                    auction.currentBidOwner,
                    auction.currentBidAmount
                );
            }
        }

        offer.isAuction = false;
        offer.isOnSale = false;
        offers[_tokenId] = offer;
    }

    function createAuction(
        address _assetAddress, // address of the XSigma721 token
        uint256 _assetId, // id of the NFT
        uint256 _startPrice, // minimum price
        uint256 _startTime, // time when the auction will start. Check the format with frontend
        uint256 _duration // duration in seconds of the auction
    ) private returns (uint256) {
        require(_assetAddress.isContract());
        ERC721 asset = ERC721(_assetAddress);
        require(asset.ownerOf(_assetId) == msg.sender);
        require(asset.getApproved(_assetId) == address(this));

        if (_startTime == 0) {
            _startTime = now;
        }

        Auction memory auction =
            Auction({
                creator: msg.sender,
                assetAddress: _assetAddress,
                assetId: _assetId,
                startTime: _startTime,
                duration: _duration,
                currentBidAmount: _startPrice,
                currentBidOwner: address(0),
                bidCount: 0
            });
        auctions.push(auction);
        uint256 index = auctions.length - 1;

        emit AuctionCreated(index, auction.creator, auction.assetAddress);

        return index;
    }

    function bid(uint256 auctionIndex) public payable returns (bool) {
        Auction storage auction = auctions[auctionIndex];
        require(auction.creator != address(0));
        require(isActive(auctionIndex));

        if (msg.value > auction.currentBidAmount) {
            // we got a better bid. Return funds to the previous best bidder
            // and register the sender as `currentBidOwner`
            if (auction.currentBidAmount != 0 && auction.currentBidOwner != auction.creator) {
                // return funds to the previuos bidder
                auction.currentBidOwner.transfer(auction.currentBidAmount);
                emit ReturnBidFunds(
                    auctionIndex,
                    auction.currentBidOwner,
                    auction.currentBidAmount
                );
            }
            // register new bidder
            auction.currentBidAmount = msg.value;
            auction.currentBidOwner = msg.sender;
            auction.bidCount = auction.bidCount.add(1);

            emit AuctionBid(auctionIndex, msg.sender, msg.value);

            return true;
        }
        return false;
    }

    function getTotalAuctions() public view returns (uint256) {
        return auctions.length;
    }

    function isActive(uint256 _auctionIndex) public view returns (bool) {
        return getStatus(_auctionIndex) == Status.active;
    }

    function isFinished(uint256 _auctionIndex) public view returns (bool) {
        return getStatus(_auctionIndex) == Status.finished;
    }

    function getStatus(uint256 _auctionIndex) public view returns (Status) {
        Auction storage auction = auctions[_auctionIndex];
        if (now < auction.startTime) {
            return Status.pending;
        } else if (now < auction.startTime.add(auction.duration)) {
            return Status.active;
        } else {
            return Status.finished;
        }
    }

    function endDate(uint256 _auctionIndex) public view returns (uint256) {
        Auction storage auction = auctions[_auctionIndex];
        return auction.startTime.add(auction.duration);
    }

    function getCurrentBidOwner(uint256 auctionIndex)
        public
        view
        returns (address)
    {
        return auctions[auctionIndex].currentBidOwner;
    }

    function getCurrentBidAmount(uint256 auctionIndex)
        public
        view
        returns (uint256)
    {
        return auctions[auctionIndex].currentBidAmount;
    }

    function getBidCount(uint256 auctionIndex) public view returns (uint256) {
        return auctions[auctionIndex].bidCount;
    }

    function getWinner(uint256 auctionIndex) public view returns (address) {
        require(isFinished(auctionIndex), "Auction not finished yet");
        return auctions[auctionIndex].currentBidOwner;
    }

    /*
    function claimFunds(uint256 auctionIndex) public {
        require(isFinished(auctionIndex), "The auction is still active");
        Auction storage auction = auctions[auctionIndex];

        require(
            auction.creator == msg.sender,
            "You are not the creator of the auction"
        );
        address payable auctionCreator = payable(auction.creator);
        // TODO transfer substracting the commision
        auctionCreator.transfer(auction.currentBidAmount);

        XSigma721 asset = XSigma721(auction.assetAddress);
        address creatorNFT = asset.getCreator(auction.assetId);
        // TODO transfer royalties
        emit Royalties(creatorNFT, auction.currentBidAmount);

        emit Claim(auctionIndex, auction.creator);
    }
*/
    function claimAsset(uint256 auctionIndex) public {
        require(isFinished(auctionIndex), "The auction is still active");
        Auction storage auction = auctions[auctionIndex];

        address winner = getWinner(auctionIndex);
        require(winner == msg.sender, "You are not the winner of the auction");

        // the token could be sold in direct sale or the owner cancelled the auction
        Offer memory offer = offers[auction.assetId];
        require(offer.isAuction == true, "NFT not in auction");       

        XSigma721 asset = XSigma721(auction.assetAddress);
        asset.transferFrom(auction.creator, winner, auction.assetId);

        emit Claim(auctionIndex, winner);

        // now, pay the amount - commision - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(auction.assetId));
        uint256 commisionToPay = (auction.currentBidAmount * commision) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT == auction.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay =
                (auction.currentBidAmount *
                    asset.getRoyalties(auction.assetId)) /
                10000;
            creatorNFT.transfer(royaltiesToPay);
            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay =
            auction.currentBidAmount - commisionToPay - royaltiesToPay;

        auction.creator.transfer(amountToPay);
        emit PaymentToOwner(
            auction.creator,
            amountToPay,
            auction.currentBidAmount,
            (auction.currentBidAmount * commision) / 10000,
            amountToPay + ((auction.currentBidAmount * commision) / 10000)
        );

        offer.isAuction = false;
        offer.isOnSale = false;
        offers[auction.assetId] = offer;
    }

    function extractBalance() public onlyOwner {
        //   emit Payment(msg.sender, address(this).balance);
        msg.sender.transfer(address(this).balance);
    }
}
