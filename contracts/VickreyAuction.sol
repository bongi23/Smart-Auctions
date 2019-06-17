pragma solidity >=0.4.22 <0.7.0;

import "./Auction.sol";
import "./Escrow.sol";

contract VickreyAuction is Auction {
    
    struct Bid {
        bytes32 bidHash;
        uint value;
        bool opened;
        bool withdrawn;
        bool refund;
    }
    
    enum Phases {
        CommitmentPhase,
        WithdrawalPhase,
        OpeningPhase,
        Finished
    }
    
    /*static variables after contract construction*/
    address payable charity;
    
    uint public depositRequirement;
    uint escrowDuration;
    
    uint public start = block.number; /*grace period ignored*/
    uint public endCommitment;

    uint public startWithdrawal;
    uint public endWithdrawal;
    
    uint public startOpening;
    uint public end;
    
    /*state of the auction*/
    Phases public phase = Phases.CommitmentPhase;
    mapping(address => Bid) public bids; /*for storing the bids of every bidder*/
    uint public priceToPay; /* 2nd highest bid */
    bool public sold;
    
    uint refundLeft;
    
    event LogEnvelopeCommited(address);
    event LogEnvelopeWithdrawn(address);
    event LogVoidBid(address, uint);
    event LogLosingBid(address, uint);
    event LogUpdateSecondPrice(uint, uint);
    
    modifier duringPhase(Phases _phase) {
        require(phase == _phase, "Function not allowed in this phase"); _;
    }
    
    /*time flow simulation*/
    modifier blockTimedTransition() {
        if(!debug) {
            if(phase == Phases.CommitmentPhase && block.number > endCommitment)
                nextPhase();
            if(phase == Phases.WithdrawalPhase && block.number > endWithdrawal)
                nextPhase();
            if(phase == Phases.OpeningPhase && block.number > end)
                nextPhase();
        }
        _;
    }
    
     modifier only_auctioneer_seller_buyer {
        require(msg.sender == auctioneer || msg.sender == seller || msg.sender == highestBidder, "Unauthorized"); _;
    }
    
    modifier eligibleForRefund {
        require(bids[msg.sender].opened && !bids[msg.sender].refund, "Bidder is not eligible for refund"); _;
    }
    
    /*state transition function*/
    function nextPhase() internal {
        phase = Phases(uint(phase) + 1);
        emit LogPhaseTransition(phaseToString(phase));
    }
    
    /*utility function, may be deleted in a real deployment*/
    function phaseToString(Phases _phase) internal pure returns (string memory) {
        if(_phase == Phases.CommitmentPhase) return "Commitment phase";
        if(_phase == Phases.WithdrawalPhase) return "Withdrawal phase";
        if(_phase == Phases.OpeningPhase) return "Opening phase";
        if(_phase == Phases.Finished) return "Finished phase";
    }
    
    /*utility function for change between states when debugging*/
    function nextPhase(Phases _phase) public onlyDebugging{
        phase = _phase;
        emit LogPhaseTransition(phaseToString(phase));
    }
    
    /* debug function used to obtain a fake envelope*/
    function debug_keccak(bytes32 nonce, uint val) public view onlyDebugging returns (bytes32) {
        return keccak256(abi.encode(nonce,val));
    }
    
    constructor (address payable _seller, address payable _charity, uint _reserve_price, uint _commitment_phase_length, uint _withdrawal_phase_length, 
                    uint _opening_phase_length, uint _deposit_requirement, uint _escrow_duration, bool _debug) public {
        
        require(_deposit_requirement > 0, "Deposit requirement must be greater than zero");
        require(_reserve_price > 0, "Reserve price must be greater than zero");
        require(_deposit_requirement >= _reserve_price/4 && _deposit_requirement <= _reserve_price/2, "Deposit requiremente out of range");
        require(_commitment_phase_length > 0 && _withdrawal_phase_length > 0 && _opening_phase_length > 0, "Phase's length cannot be zero");        

        seller = _seller;
        charity = _charity;

        depositRequirement  = _deposit_requirement;
        reservePrice = _reserve_price;

        endCommitment = start+_commitment_phase_length;
        
        startWithdrawal = endCommitment+1;
        endWithdrawal = startWithdrawal+_withdrawal_phase_length;
        
        startOpening = endWithdrawal+1;
        end = startOpening+_opening_phase_length;
        
        escrowDuration = _escrow_duration;
        debug = _debug;
        
        emit LogAuctionStarting(start, end);
    }
    
    function commit(bytes32 _envelope) public payable blockTimedTransition duringPhase(Phases.CommitmentPhase) notTheSeller notTheAuctioneer costs(depositRequirement) {
        require(bids[msg.sender].bidHash == "", "Bidder has already sent his envelope");

        bids[msg.sender].bidHash = _envelope;
        
        emit LogEnvelopeCommited(msg.sender);
        
    }
    
    function withdraw_envelope() public blockTimedTransition duringPhase(Phases.WithdrawalPhase) {
        require(bids[msg.sender].withdrawn == false, "Bidder has already withdrawn");
        
        bids[msg.sender].withdrawn = true;
        emit LogEnvelopeWithdrawn(msg.sender);

        msg.sender.transfer(depositRequirement/2);
        
    }
    
    function open(bytes32 nonce) public payable blockTimedTransition duringPhase(Phases.OpeningPhase) {
        require(bids[msg.sender].bidHash != 0 && !bids[msg.sender].opened && !bids[msg.sender].withdrawn, "Bidder not allowed to open");

        bytes32 hash = keccak256(abi.encode(nonce, msg.value));
        require(hash == bids[msg.sender].bidHash, "Invalid nonce or bid");
        
        bids[msg.sender].opened = true;
        bids[msg.sender].value = msg.value;
        
        /* The bid is void*/
        if(msg.value < reservePrice) {
            bids[msg.sender].refund = true;
            emit LogVoidBid(msg.sender, msg.value);
            msg.sender.transfer(msg.value+(depositRequirement/2));
        } else {    
            /*The bid opened is the first one*/
            if(highestBid == 0) {
                priceToPay = reservePrice; 
                highestBid = msg.value;
                highestBidder = msg.sender;
                emit LogHighestBid(msg.sender, msg.value, reservePrice);
            }
            /*The bid opened is a losing one*/
            else if(msg.value <= highestBid ) {
                /*...but it is the second highest one*/
                if(msg.value >= priceToPay) {
                    priceToPay = msg.value;
                    emit LogUpdateSecondPrice(msg.value, priceToPay);

                }
                /*here the bidder can be immediately refund*/
                bids[msg.sender].refund = true;
                uint full_refund = msg.value+depositRequirement;
                emit LogLosingBid(msg.sender, msg.value);
                msg.sender.transfer(full_refund);
            }
            /*the opened bid is the highest one*/
            else {
                priceToPay = highestBid;
                highestBid = msg.value;
                highestBidder = msg.sender;
                emit LogHighestBid(msg.sender, msg.value, priceToPay);
                refundLeft++;
                /*cannot refund the previous highest bidder, it will violate the Withdrawal pattern*/
            }
        }
    }
    
    function finalize(bool escrow) public blockTimedTransition duringPhase(Phases.Finished) only_auctioneer_seller_buyer returns (bool){
        require(!sold, "Auction already concluded");
        require(msg.sender == auctioneer, "Finalize can be called only by the auctioneer");
        require(refundLeft == 0, "Wait until all the bidders get refunded");
        
        if(highestBid == 0) {
            emit LogUnsold();
            return false;
        }
        sold = true;
        /* deploy of the escrow contract */
        if(escrow) {
            Escrow e = (new Escrow).value(priceToPay)(seller, highestBidder, debug, 50);
            emit LogEscrowCreated(address(e));
        }
        else 
            seller.transfer(priceToPay);
        /*send fund of bad bidders to charity*/
        charity.transfer(address(this).balance);
        
        return true;
    }
    
    function askRefund() public blockTimedTransition duringPhase(Phases.Finished) eligibleForRefund {
        bids[msg.sender].refund = true;
        refundLeft--;
       
        uint refund;
        
        if(msg.sender == highestBidder)
            refund = depositRequirement+(highestBid-priceToPay);
        else
            refund = depositRequirement+bids[msg.sender].value;
        
        msg.sender.transfer(refund);
    }
}