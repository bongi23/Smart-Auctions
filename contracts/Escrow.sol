pragma solidity >=0.4.22 <0.6.0;

contract Escrow {

    uint funds;
    address seller;
    address buyer;

    bytes32 buyer_nonce;

    constructor(address _seller, address _buyer) public payable {
        require(_seller != _buyer);
        require(msg.value > 0);

        seller = _seller;
        buyer = _buyer;
    }

    
}