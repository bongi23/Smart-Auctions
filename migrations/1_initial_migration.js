const Migrations = artifacts.require("Migrations");
const EnglishAuction = artifacts.require("EnglishAuction");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(EnglishAuction, 10, 15, 5000, 1000, 3);
};
