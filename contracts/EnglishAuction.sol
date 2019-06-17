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
    
    /*static variables after contract construction*/
    uint start = block.number; 
    uint end;
    address payable seller = msg.sender;
    uint public unchallengedInterval; 
    uint8 public minIncrement; /*percentage w.r.t. the highest bid*/
    uint public buyoutPrice;

    /* auction state*/
    Phases public phase = Phases.Started;
    uint public bidBlock;
    
    mapping(address => uint) pendingRefunds; /* refunds of bidders, to implement withdrawal pattern */

    event LogSoldByBuyout(address, uint);
    event LogWithdrawalExecuted(address, uint);
    
    /*time flow simulation*/
    modifier blockTimedTransition {
        if(!debug) {
            if(phase == Phases.BidReceived && (block.number > end || block.number > bidBlock+unchallengedInterval)) {
                phase = Phases.Sold; 
                emit LogSold(highestBidder, highestBid);
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

    modifier hasPendingRefunds() {
        require(pendingRefunds[msg.sender] > 0); _;
    }
    
    function nextPhase(Phases _phase) onlyDebugging public {
        phase = _phase;
        emit LogPhaseTransition(phaseToString(phase));
    }
    
    /*utility function, may be deleted in a real deployment*/
    function phaseToString(Phases _phase) internal pure returns (string memory) {
        if(_phase == Phases.Started) return "Started phase";
        if(_phase == Phases.BidReceived) return "BidReceived phase";
        if(_phase == Phases.Finished) return "Finished phase";
    }
    
    constructor (uint _duration, uint8 _min_increment, uint _buyout_price, uint _reserve_price, 
                    uint _unchallenged_interval, bool _debug) public {
        require(_min_increment >= 1 && _min_increment <= 100, "Minimum increment out of range");
        require(_buyout_price > _reserve_price, "Buyout price must be greater than reserve price");
        require(_buyout_price > 0, "Buyout price must be bigger than zero");
        require( _reserve_price > 0, "Reserve price must be greater than 0");
        require(_duration > 0, "Auction duration must be greater than 0");
        
        unchallengedInterval = _unchallenged_interval;
        minIncrement = _min_increment;
        buyoutPrice = _buyout_price;
        reservePrice = _reserve_price;
        
        end = start+_duration;
        
        debug = _debug;

        emit LogAuctionStarting(start, end);
    }
    
    /*called by someone that wants to buy the good at buyout price*/
    function buyNow() public payable blockTimedTransition duringPhase(Phases.Started) notTheSeller notTheAuctioneer costs(buyoutPrice) {

        phase = Phases.Sold;        
        
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        emit LogSoldByBuyout(msg.sender, buyoutPrice);
    }
    
    function bid() public payable blockTimedTransition notTheSeller {
        require(phase == Phases.Started || phase == Phases.BidReceived, "Bid not allowed in this phase");
        require(msg.sender != highestBidder);
        
        /* first bid received*/
        if(phase == Phases.Started) {
            require(msg.value >= reservePrice, "Bid must be greater than reserve price");
            
            highestBid = msg.value;
            highestBidder = msg.sender;
            bidBlock = block.number;
            
            phase = Phases.BidReceived;
            emit LogPhaseTransition(phaseToString(phase));
        }
        else {
            uint increment = highestBid*minIncrement/100;
            require(msg.value >= highestBid + increment, "Bid must be grester than the highest of at least minIncrement percent");
            
            address payable refund_address = highestBidder;
            uint refund = highestBid;
            
            highestBid = msg.value;
            highestBidder = msg.sender;
            bidBlock = block.number;
            
            pendingRefunds[refund_address] += refund; /*needed to remember that the bidder has to be refunded*/
            
            emit LogHighestBid(msg.sender, msg.value, refund);
        }
    }
    
    function finalize(bool escrow) public blockTimedTransition duringPhase(Phases.Sold) {
        require(auctioneer == msg.sender, "Only the auctioneer can finalize the auction");
        
        phase = Phases.Finished;
        
        if(escrow) {
            Escrow e = (new Escrow).value(highestBid)(seller, highestBidder, debug, 50);
            emit LogEscrowCreated(address(e));
        }

        else seller.transfer(highestBid);
    }

    function withdrawal() public hasPendingRefunds {

        uint refund = pendingRefunds[msg.sender];
        pendingRefunds[msg.sender] = 0;
        
        emit LogWithdrawalExecuted(msg.sender, refund);
        
        msg.sender.transfer(refund);
    }
}
