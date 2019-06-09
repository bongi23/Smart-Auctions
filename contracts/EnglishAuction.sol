pragma solidity >=0.4.22 <0.6.0;

contract EnglishAuction {
    
    /// static after constructor
    address payable seller = msg.sender;
    uint public bid_expiration; /// can be smaller?
    uint8 public min_increment; /// percentual wrt the highest bid
    uint public buyout_price;
    uint public reserve_price;
    uint public start_time = block.number + 1;
    uint public duration; /// can be smaller?
    
    /// auction state
    address payable public highest_bidder;
    uint public highest_bid = 0;
    uint public bid_block = 0;
    bool public sold = false;
    bool public paid = false;
    
    mapping(address => uint) pending_refunds; /// funds of bidders, implementing withdrawal pattern

    event AuctionStarting(uint);
    event SoldByBuyout(address, uint);
    event Sold(address, uint);
    event Unsold();
    event OfferOutbid(address);
    event WithdrawalExecuted(address, uint);
    
    modifier when_auction_is_open() {
            require(block.number >= start_time && start_time+duration >= block.number); _;
    }
    
    modifier when_auction_is_close_OR_sold() {
            require(block.number > start_time+duration || sold); _;
    }

    modifier when_offer_outbid() {
        require(pending_refunds[msg.sender] > 0); _;
    }
    
    modifier not_the_seller() {
        require(seller != msg.sender); _;
    }
    
    ///modifier only_the_seller() {
    ///    require(seller == msg.sender); _;
    ///}
    
    constructor (uint _duration, uint8 _min_increment, uint _buyout_price, uint _reserve_price, uint _bid_expiration) public {
        require(_min_increment >= 1 && _min_increment <= 100);
        require(_buyout_price > _reserve_price);
        require(_buyout_price > 0);
        require( _reserve_price > 0);
        
        bid_expiration = _bid_expiration;
        min_increment = _min_increment;
        buyout_price = _buyout_price;
        reserve_price = _reserve_price;
        
        duration = _duration; /// how many blocks until auction expiration 
        
        emit AuctionStarting(duration);
    }
    
    function buy_now() public payable when_auction_is_open not_the_seller {
        require(sold == false);
        require(highest_bid == 0);
        require(msg.value >= buyout_price); /// maybe equal?
        
        sold = true;
        highest_bidder = msg.sender;
        highest_bid = msg.value;
        
        emit SoldByBuyout(msg.sender, buyout_price);
    }
    
    function bid() public payable when_auction_is_open not_the_seller {
        require(msg.sender != highest_bidder);
        
        if(highest_bid > 0 && bid_block+bid_expiration < block.number) {
            sold = true;
            emit Sold(highest_bidder, highest_bid);
        }
        require(sold == false);
        
        if(highest_bid == 0) { /// first bid
            require(msg.value >= reserve_price);
            
            highest_bid = msg.value;
            highest_bidder = msg.sender;
            bid_block = block.number;
        }
        else {
            uint increment = highest_bid*min_increment/100;
            require(msg.value >= highest_bid + increment);
            
            address payable refund_address = highest_bidder;
            uint refund = highest_bid;
            
            highest_bid = msg.value;
            highest_bidder = msg.sender;
            bid_block = block.number;
            
            pending_refunds[refund_address] = refund;
            
            emit OfferOutbid(refund_address);
        }
    }
    
    function finalize() public when_auction_is_close_OR_sold {
        require(paid == false);
        require(highest_bidder == msg.sender || seller == msg.sender);
        
        paid = true;
        if(!sold) 
            emit Unsold();
        else
            seller.transfer(highest_bid);
    }

    function withdrawal() public when_offer_outbid {
        uint refund = pending_refunds[msg.sender];
        pending_refunds[msg.sender] = 0;
        
        emit WithdrawalExecuted(msg.sender, refund);
        
        msg.sender.transfer(refund);
    }
}