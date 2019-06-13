pragma solidity >=0.4.22 <0.6.0;

contract Escrow {

    uint public funds;
    uint created = block.number;
    uint expiration;
    address payable seller;
    address payable buyer;

    bytes32 buyer_hash;
    string expedition_number;
    
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
    
    function set_hash(bytes32 hash) public {
        require(block.number <= expiration);
        require(msg.sender == buyer);
        
        buyer_hash = hash;
    }
    
    function set_expedition_number(string memory en) public {
        require(bytes(expedition_number).length != 0 && bytes(en).length != 0);
        require(msg.sender == seller);
        require(block.number <= expiration);
        
        expedition_number = en; /// suppose it is valid
    }
    
    function verify_hash(uint nonce) public {
        require(!paid);
        require(msg.sender == seller && buyer_hash.length != 0);
        require(block.number <= expiration);
        
        bytes32 seller_hash = keccak256(abi.encode(nonce));
        require(seller_hash == buyer_hash);
        paid = true;
        seller.transfer(funds);
    }
    
    function refund_seller() public {
        require(block.number > expiration);
        require(bytes(expedition_number).length > 0);
        require(msg.sender == seller);
        require(!paid && !refunded);
        
        paid = true;
        seller.transfer(funds);
    }
    
    function refund_buyer() public {
        require(block.number > expiration);
        require(bytes(expedition_number).length == 0);
        require(msg.sender == buyer);
        require(buyer_hash.length > 0);
        require(!refunded && !paid);
        
        refunded = true;
        buyer.transfer(funds);
    }
    
    function balance () public view returns (uint){
        require(debug);
        return address(this).balance;
    }
    
}