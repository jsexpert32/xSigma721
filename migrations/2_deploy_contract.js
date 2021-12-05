var NFTToken = artifacts.require("XSigma721");
var engine = artifacts.require("Engine");

module.exports = function(deployer) {
    deployer.deploy(NFTToken);
    deployer.deploy(engine);
};