const NFTItem = artifacts.require("XSigma721");
const Engine = artifacts.require("Engine");
const helper = require('../utils/utils.js');

contract("XSigma721 Marketplace", accounts => {

  var owner = accounts[0];
  var instance;
  var engine;

  before(async function () {
    // set contract instance into a variable
    instance = await NFTItem.deployed();
    engine = await Engine.deployed();
  })

  it("Should be deployed", async () => {
    assert.notEqual(instance, null);
    assert.notEqual(engine, null);
  });

  it("initializes with empty list of auctions", async function () {
    let count = await engine.getTotalAuctions();
    assert.equal(count, 0);
  });

  it("Should create nft", async () => {
    var tokenId = await instance.createItem("www.luispando.com", 200, { from: owner });
    //  console.log("The tokenId is = " + JSON.stringify(tokenId));
    assert.notEqual(tokenId, null);
  });

  it("Should create 2nd nft", async () => {
    var tokenId = await instance.createItem("www.luispando2.com", 200, { from: owner });
    //   console.log("The tokenId is = " + JSON.stringify(tokenId));
    assert.notEqual(tokenId, null);
  });

  it("Should create 3rd nft", async () => {
    var tokenId = await instance.createItem("www.luispando2.com", 300, { from: owner });
    //   console.log("The tokenId is = " + JSON.stringify(tokenId));
    assert.notEqual(tokenId, null);
  });

  it("should create an auction", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(2);
    assert.equal(owner, accounts[0]);

    // allow engine to transfer the nft
    await instance.approve(engine.address, 2, { from: accounts[0] });

    // create auction
    await engine.createOffer(instance.address, 2, true, true, 10000000000000, 0, 0, 10, { from: accounts[0] });
  
    // make sure auction was created
    let count = await engine.getTotalAuctions();
    assert.equal(count, 1);
  });

  it("should allow bids", async function () {
    // create auction
    let balanceIniBeforeBidding = await web3.eth.getBalance(accounts[1]);
    await engine.bid(0, { from: accounts[1], value: 1000000000000000 });
    let balanceIni = await web3.eth.getBalance(accounts[1]);
    await engine.bid(0, { from: accounts[2], value: 1120000000000000 });
    let balanceEnd = await web3.eth.getBalance(accounts[1]);
    console.log("Balance bidder before bidding " + balanceIniBeforeBidding + " Balance bidder after " + balanceIni + " -- balance bidder with returning funds " + balanceEnd);

    var currentBid = await engine.getCurrentBidAmount(0);
    assert.equal(currentBid, 1120000000000000);
  });

  it("should get winner when finished", async function () {
    await helper.advanceTimeAndBlock(20); // wait 20 seconds in the blockchain
    var winner = await engine.getWinner(0);
    assert.equal(winner, accounts[2]);
  });

  it("should let winner claim assets", async function () {
    var offer = await engine.offers(2);
    console.log(JSON.stringify(offer));
    const ownerBefore = await instance.ownerOf(2);
    assert.equal(ownerBefore, accounts[0]);
    await engine.claimAsset(0, { from: accounts[2] });
    const ownerAfter = await instance.ownerOf(2);
    assert.equal(ownerAfter, accounts[2]);
  });

  it("Should show URL", async () => {
    let url = await instance.tokenURI(1);
    //   console.log("The tokenURI is = " + url);
    assert.equal(url, "www.luispando.com");

    const url2 = await instance.tokenURI(2);
    //  console.log("The tokenURI is = " + url2);
    assert.equal(url2, "www.luispando2.com");

    url = await instance.tokenURI(1);
    assert.equal(url, "www.luispando.com");
  });

  it("Should show the owner", async () => {
    const ownerResult = await instance.ownerOf(1);
    //    console.log("The owner is = " + ownerResult);
    assert.equal(ownerResult, accounts[0]);
  });

  it("Should transfer ownership when buying", async () => {
    const buyer = accounts[1];
    const ownerResult1 = await instance.ownerOf(1);
    let balanceIni = await web3.eth.getBalance(ownerResult1);
    let contractBalanceIni = await web3.eth.getBalance(instance.address);
    // allow engine to transfer the nft
    await instance.approve(engine.address, 1, { from: accounts[0] });
    await engine.createOffer(instance.address, 1, true, false, 10000000000000, 0, 0, 0, { from: accounts[0] });
    try { await engine.buy(1, { from: buyer, value: 3200000000000 }); }
    catch (error) { assert.equal(error.reason, "Price is not enough"); }

    await engine.buy(1, { from: buyer, value: 10000000000000 });

    const ownerResult2 = await instance.ownerOf(1);
    let balanceEnd = await web3.eth.getBalance(ownerResult1);
    let contractBalanceEnd = await web3.eth.getBalance(instance.address);

    /* console.log("The first owner is = " + ownerResult1);
     console.log("The second owner is = " + ownerResult2);
     console.log("Balance creator before " + balanceIni + " -- balance creator after "+ balanceEnd);
     console.log("Balance contract before " + contractBalanceIni + " -- balance contract after "+ contractBalanceEnd);*/
    assert.notEqual(ownerResult1, ownerResult2);
  });

  it("should create an offer", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(3);
    assert.equal(owner, accounts[0]);

    // allow engine to transfer the nft
    await instance.approve(engine.address, 3, { from: accounts[0] });

    // create auction
    await engine.createOffer(instance.address, 3, true, true, 10000000000000, 0, 0, 10, { from: accounts[0] });
    let idAuction = await engine.getAuctionId.call(3);
    console.log("idAuction = " + idAuction);


    // make sure auction was created
    let count = await engine.getTotalAuctions();
    assert.equal(count, 2);
  });


  it("should allow bids", async function () {
    // create auction
    let balanceIniBeforeBidding = await web3.eth.getBalance(accounts[1]);
    await engine.bid(1, { from: accounts[1], value: 1000000000000000 });
    let balanceIni = await web3.eth.getBalance(accounts[1]);
    await engine.bid(1, { from: accounts[2], value: 1120000000000000 });
    let balanceEnd = await web3.eth.getBalance(accounts[1]);
    console.log("Balance bidder before bidding " + balanceIniBeforeBidding + " Balance bidder after " + balanceIni + " -- balance bidder with returning funds " + balanceEnd);

    var currentBid = await engine.getCurrentBidAmount(1);
    assert.equal(currentBid, 1120000000000000);
  });

  it("should get winner when finished", async function () {
    await helper.advanceTimeAndBlock(20); // wait 20 seconds in the blockchain
    var winner = await engine.getWinner(1);
    assert.equal(winner, accounts[2]);
  });

  it("should allow a direct sell while auctioning", async function () {
    await engine.buy(3, { from: accounts[4], value: 2000000000000000 });

  });

  it("should not let winner claim the assets, as the auction was cancelled when the direct sale was made", async function () {
    const ownerBefore = await instance.ownerOf(3);
    assert.equal(ownerBefore, accounts[4]);
    try { // the error is triggered
      await engine.claimAsset(1, { from: accounts[2] });
    } catch (error) {
      assert.equal(error.reason, "NFT not in auction");
    }
    // the owner has not changed    
    const ownerAfter = await instance.ownerOf(3);
    assert.equal(ownerAfter, accounts[4]);
  });
});