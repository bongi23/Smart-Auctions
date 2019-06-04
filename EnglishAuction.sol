pragma solidity >=0.4.22 <0.6.0;

contract EnglishAuction {
    address payable seller;
    
    uint bid_expiration; /// can be smaller?
    uint8 min_increment; /// percentual wrt the highest bid
    uint40 buyout_price;
    uint40 reserve_price;
    
    address payable highest_bidder;
    uint highest_bid = 0;
    
    uint start_time = block.number + 20;
    uint duration; /// can be smaller?
    bool sold = false;
    bool paid = false;
    
    mapping(address => uint) pendig_refunds;
    
    event AuctionStarting();
    event HigestBidUpdate();
    event AuctionEnded();
    event SoldByBuyout();
    
    modifier when_auction_is_open() {
            require(block.number >= start_time && start_time+duration <= block.number); _;
    }
    
    modifier when_auction_is_close() {
            require(block.number >= start_time+duration); _;
    }
    
    constructor (uint _duration, address payable _seller, uint8 _min_increment, uint40 _buyout_price, uint40 _reserve_price, uint _bid_expiration) public {
        require(_min_increment >= 1 && _min_increment <= 100);
        require(_bid_expiration > block.number+20);
        require(_buyout_price > _reserve_price);
        require(_buyout_price > 0);
        require( _reserve_price > 0);
        
        seller = _seller;
        
        bid_expiration = _bid_expiration;
        min_increment = _min_increment;
        buyout_price = _buyout_price;
        reserve_price = _reserve_price;
        
        duration = _duration; /// how many blocks until auction expiration 
        
        emit AuctionStarting();
    }
    
    function buy_now() public payable when_auction_is_open {
        require(highest_bid == 0);
        require(sold == false);
        require(msg.value >= buyout_price); /// maybe equal?
        
        sold = true;
        highest_bidder = msg.sender;
        highest_bid = msg.value;
        
        emit SoldByBuyout();
    }
    
    function bid() public payable when_auction_is_open {
        require(sold == false);
        
        if(highest_bid == 0) { /// first bid
            require(msg.value >= reserve_price);
            
            highest_bid = msg.value;
            highest_bidder = msg.sender;
        }
        else {
            uint increment = highest_bid*min_increment/100;
            require(msg.value >= highest_bid + increment);
            
            address payable refund_address = highest_bidder;
            uint refund = highest_bid;
            
            highest_bid = msg.value;
            highest_bidder = msg.sender;
            
            refund_address.transfer(refund); /// IMPLEMENT WITHDRAWL PATTERN
        }
    }
    
    function finalize() public when_auction_is_close {
        require(paid == false);
        require(msg.sender == seller);
        
        if(sold) { /// CHECK-EFFECTS-INTERACTION
            paid = true;
            seller.transfer(highest_bid);
        }
    }
}
