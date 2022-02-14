const Factory = artifacts.require("./Main.sol");
const TestERC20 = artifacts.require("./TestERC20.sol");

module.exports = function(deployer) {
  deployer.deploy(Factory)
  deployer.deploy(TestERC20)
};