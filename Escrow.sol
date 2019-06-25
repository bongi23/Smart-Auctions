pragma solidity >=0.4.22 <0.6.0;

contract Escrow {
    
    /*static variables after contract construction*/
    uint public funds;
    uint created = block.number;
    uint expiration;
    address payable seller;
    address payable buyer;
    
    /*state of the escrow*/
    bytes32 buyerHash;
    string expeditionNumber;
    
    bool debug;
    bool paid;
    bool refunded;

    constructor(address payable _seller, address payable _buyer, bool _debug, uint _expiration) public payable {
        require(_seller != _buyer);
        require(msg.value > 0);

        seller = _seller;
        buyer = _buyer;
        
        debug = _debug;
        
        expiration = created+_expiration;
    }
    
    function setHash(bytes32 hash) public {
        require(block.number <= expiration, "Buyer cannot set hash if auction has expired");
        require(msg.sender == buyer, "only the buyer can communicate the hash");
        
        buyerHash = hash;
    }
    
    function setExpeditionNumber(string memory en) public {
        require(bytes(expeditionNumber).length == 0, "Expedition number can be set only once");
        require(bytes(en).length != 0, "Expedition number cannot have zero length");
        require(msg.sender == seller, "Only the seller can communicate expedition number");
        require(block.number <= expiration, "Expedition number cannot be communicate after escrow expiration");
        
        expeditionNumber = en; /// suppose it is valid
    }
    
    function verifyHash(uint nonce) public {
        require(!paid, "The good has been already paid");
        require(msg.sender == seller && buyerHash != "", "Only the seller can verify the hash of the buyer");
        require(block.number <= expiration, "hash can be verified only before expiration");
        
        bytes32 sellerHash = keccak256(abi.encode(nonce));
        require(sellerHash == buyerHash);
        paid = true;
        seller.transfer(funds);
    }
    
    function refundSeller() public {
        require(block.number > expiration, "Seller can ask refund only after escrow expiration");
        require(bytes(expeditionNumber).length > 0, "Seller must have provided the expedition number before asking a refund");
        require(msg.sender == seller, "Only the sller can call this function");
        require(!paid && !refunded, "seller can be refunded only once and only if he has not been paid yet");
        
        paid = true;
        seller.transfer(funds);
    }
    
    function refundBuyer() public {
        require(block.number > expiration, "buyer can ask refund only after escrow expiration");
        require(bytes(expeditionNumber).length == 0, "buyer can be refunded only if the sleer has not provided a valid expedition number");
        require(msg.sender == buyer, "Only the buyer canc all this function");
        require(buyerHash != "", "The buyer must have provided an hash in order to be refunded");
        require(!refunded && !paid, "The buyer can be refunded only once and only if the good has not been paid yet");
        
        refunded = true;
        buyer.transfer(funds);
    }
    
    function balance () public view returns (uint){
        require(debug);
        return address(this).balance;
    }
    
}