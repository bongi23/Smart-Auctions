pragma solidity >=0.4.22 <0.6.0;

import "./Auction.sol";
import "./Escrow.sol";

contract EnglishAuction is Auction {
    
    /// static after constructor
    address payable seller = msg.sender;
    uint public unchallenged_interval; /// can be smaller?
    uint8 public min_increment; /// percentual wrt the highest bid
    uint public buyout_price;
    uint public start_time = block.number;
    uint public duration; /// can be smaller?
    
    /// auction state
    uint public bid_block;
    bool public sold = false;
    bool public paid = false;
    
    mapping(address => uint) pending_refunds; /// funds of bidders, implementing withdrawal pattern

    event LogSoldByBuyout(address, uint);
    event LogWithdrawalExecuted(address, uint);
    
    modifier when_auction_is_open() {
        if(!debug)
            require(block.number >= start_time && start_time+duration >= block.number); _;
    }
    
    modifier when_auction_is_close_OR_sold() {
        if(!debug)    
            require(block.number > start_time+duration || sold); _;
    }

    modifier has_pending_funds() {
        require(pending_refunds[msg.sender] > 0); _;
    }
    
    modifier not_the_seller() {
        require(seller != msg.sender); _;
    }
    
    ///modifier only_the_seller() {
    ///    require(seller == msg.sender); _;
    ///}
    
    constructor (uint _duration, uint8 _min_increment, uint _buyout_price, uint _reserve_price, 
                    uint _unchallenged_interval) public {
        require(_min_increment >= 1 && _min_increment <= 100);
        require(_buyout_price > _reserve_price);
        require(_buyout_price > 0);
        require( _reserve_price > 0);
        
        unchallenged_interval = _unchallenged_interval;
        min_increment = _min_increment;
        buyout_price = _buyout_price;
        reserve_price = _reserve_price;
        
        duration = _duration; /// how many blocks until auction expiration 
        end = start+duration;

        emit LogAuctionStarting(start, end);
    }
    
    function buy_now() public payable when_auction_is_open not_the_seller {
        require(sold == false);
        require(highest_bid == 0);
        require(msg.value >= buyout_price); /// maybe equal?
        
        sold = true;
        highest_bidder = msg.sender;
        highest_bid = msg.value;
        
        emit LogSoldByBuyout(msg.sender, buyout_price);
    }
    
    function bid() public payable when_auction_is_open not_the_seller {
        require(msg.sender != highest_bidder && !sold);
        require(sold == false);

        if(highest_bid > 0 && bid_block+unchallenged_interval < block.number) {
            sold = true;
            emit LogSold(highest_bidder, highest_bid);
            return;
        }
        
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
            
            pending_refunds[refund_address] = refund; /// withdrawal pattern
            
            emit LogHighestBid(msg.sender, msg.value, refund);
        }
    }
    
    function finalize() public when_auction_is_close_OR_sold {
        require(paid == false);
        require(highest_bidder == msg.sender || seller == msg.sender);
        
        paid = true;
        if(!sold) 
            emit LogUnsold();
        else {
            Escrow e = (new Escrow).value(highest_bid)(seller, highest_bidder, debug, 50);
            emit LogEscrowCreated(address(e));
        }

    }

    function withdrawal() public has_pending_funds {
        uint refund = pending_refunds[msg.sender];
        pending_refunds[msg.sender] = 0;
        
        emit LogWithdrawalExecuted(msg.sender, refund);
        
        msg.sender.transfer(refund);
    }
}
