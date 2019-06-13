const Migrations = artifacts.require("Migrations");

//const EnglishAuction = artifacts.require("EnglishAuction");
const VickreyAuction = artifacts.require("VickreyAuction");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Migrations);
  /*params: _seller, _reserve_price, _commitment_phase_length, _withdrawal_phase_length, _opening_phase_length, 
    _deposit_requirement, _escrow_duration, _debug */
  deployer.deploy(VickreyAuction, accounts[1], 500, 1, 1, 1, 250, 1, true);
  
  // deployer.deploy(EnglishAuction, 10, 15, 5000, 1000, 3);
};
