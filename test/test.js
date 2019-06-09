const EA = artifacts.require("EnglishAuction");
contract("EnglishAuction", accounts => {
it("should test the correctness of the functions", () => {
    // MyContract is a contract artifact (ABI), not the instance itself.
    // We cannot call the functions on the artifact.
    // We need to retrieve the deployed instance first
    EA.deployed() // Retrieve the last instance of MyContract
       .then(instance => {
            // instance is the instance of MyContract
            instance.buyout_price().then(result => {
                // result is the result of myFunction(): solidity’s uint are BigNumber objets
                assert.equal(result.toNumber(), 5000, "Result should be 5000");
 }); }); }); });