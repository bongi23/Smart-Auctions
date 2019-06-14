pragma solidity >=0.4.22 <0.6.0;

import "./Auction.sol";
import "./Escrow.sol";

contract EnglishAuction is Auction {
    
    enum Phases {
        Started,
        BidReceived,
        Sold,
        Finished
    }
    /// static after constructor
    address payable seller = msg.sender;
    uint public unchallenged_interval; /// can be smaller?
    uint8 public min_increment; /// percentual wrt the highest bid
    uint public buyout_price;
    uint public start_time = block.number;

    /// auction state
    Phases public phase = Phases.Started;
    uint public bid_block;
    
    mapping(address => uint) pending_refunds; /// funds of bidders, implementing withdrawal pattern

    event LogSoldByBuyout(address, uint);
    event LogWithdrawalExecuted(address, uint);
    
    modifier blockTimedTransition {
        if(!debug) {
            if(phase == Phases.BidReceived && (block.number > end || block.number > bid_block+unchallenged_interval)) {
                phase = Phases.Sold; 
                emit LogSold(highest_bidder, highest_bid);
            }
            else if(phase == Phases.Started && block.number > end) {
                phase = Phases.Finished;
                emit LogPhaseTransition(phaseToString(phase));
            }
        }
        _;
    }
    
    modifier duringPhase(Phases _phase) {
        require(phase == _phase); _;
    }

    modifier has_pending_refunds() {
        require(pending_refunds[msg.sender] > 0); _;
    }
    
    modifier not_the_seller() {
        require(seller != msg.sender); _;
    }
    
    function nextPhase(Phases _phase) public {
        require(debug);
        phase = _phase;
        emit LogPhaseTransition(phaseToString(phase));
    }
    
    function phaseToString(Phases _phase) internal pure returns (string memory) {
        if(_phase == Phases.Started) return "Started phase";
        if(_phase == Phases.BidReceived) return "BidReceived phase";
        if(_phase == Phases.Finished) return "Finished phase";
    }
    
    constructor (uint _duration, uint8 _min_increment, uint _buyout_price, uint _reserve_price, 
                    uint _unchallenged_interval) public {
        require(_min_increment >= 1 && _min_increment <= 100);
        require(_buyout_price > _reserve_price);
        require(_buyout_price > 0);
        require( _reserve_price > 0);
        require(_duration > 0);
        
        unchallenged_interval = _unchallenged_interval;
        min_increment = _min_increment;
        buyout_price = _buyout_price;
        reserve_price = _reserve_price;
        
        end = start+_duration;

        emit LogAuctionStarting(start, end);
    }
    
    function buy_now() public payable blockTimedTransition duringPhase(Phases.Started) not_the_seller costs(buyout_price) {

        phase = Phases.Sold;        
        
        highest_bidder = msg.sender;
        highest_bid = msg.value;
        
        emit LogSoldByBuyout(msg.sender, buyout_price);
    }
    
    function bid() public payable blockTimedTransition not_the_seller {
        require(phase == Phases.Started || phase == Phases.BidReceived);
        require(msg.sender != highest_bidder);
        
        if(phase == Phases.Started) { /// first bid
            require(msg.value >= reserve_price);
            
            highest_bid = msg.value;
            highest_bidder = msg.sender;
            bid_block = block.number;
            
            phase = Phases.BidReceived;
            emit LogPhaseTransition(phaseToString(phase));
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
    
    function finalize() public blockTimedTransition duringPhase(Phases.Sold) {
        require(highest_bidder == msg.sender || seller == msg.sender);
        
        phase = Phases.Finished;
        
        Escrow e = (new Escrow).value(highest_bid)(seller, highest_bidder, debug, 50);
        emit LogEscrowCreated(address(e));
        

    }

    function withdrawal() public has_pending_refunds {
        require(msg.sender != highest_bidder); // superfluo, il suo refund è a 0
        
        uint refund = pending_refunds[msg.sender];
        pending_refunds[msg.sender] = 0;
        
        emit LogWithdrawalExecuted(msg.sender, refund);
        
        msg.sender.transfer(refund);
    }
}
