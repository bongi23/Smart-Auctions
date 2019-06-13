let VA = artifacts.require("VickreyAuction");
contract("VickreyAuction", accounts => {
    it("should commit several bid", () => {
    // MyContract is a contract artifact (ABI), not the instance itself.
    // We cannot call the functions on the artifact.
    // We need to retrieve the deployed instance first
        VA.deployed() // Retrieve the last instance of MyContract
        .then(instance => {
                // instance is the instance of MyContract
                instance.debug_keccak.call('0x01', 1000).then(result => {
                    // result is the result of myFunction(): solidity’s uint are BigNumber objets
                    instance.commit.call(result, {from : accounts[5]});
 }); }); }); });