pragma solidity >=0.4.21 <0.6.0;

import "./Auction.sol";
import "./Escrow.sol";

contract VickreyAuction is Auction {
    
    struct Bid {
        bytes32 bid_hash;
        uint value;
        bool opened;
        bool withdrawn;
        bool refund;
    }
    
    /// static after contract constructor
    address payable seller;
    address payable auctioneer = msg.sender;
    address payable charity;
    uint public reserve_price;
    uint public commitment_phase_length;
    uint public withdrawal_phase_length;
    uint public opening_phase_length;
    uint public deposit_requirement;
    uint escrow_duration;
    
    uint public start = block.number; /// 20 is a grace period of about 5 mins
    uint public end_commitment;

    uint public start_withdrawal;
    uint public end_withdrawal;
    
    uint public start_opening;
    uint public end;
    
    /// state of the contract
    mapping(address => Bid) public bids;

    uint public price_to_pay; /// 2nd highest bid
    
    /// finalizing 
    bool public sold;

    event LogEnvelopeCommited(address);
    event LogEnvelopeWithdrawn(address);
    event LogVoidBid(address, uint);
    event LogLosingBid(address, uint);
    event LogUpdateSecondPrice(uint, uint);
    
    
    modifier only_during(uint start_block, uint end_block) {
        if(!debug)
            require(block.number >= start && block.number <= end); _;
    }
    
    modifier only_when_closed {
        if(!debug)
            require(block.number > end); _;
    }
    
    modifier only_auctioneer_seller_buyer {
        require(msg.sender == auctioneer || msg.sender == seller || msg.sender == highest_bidder); _;
    }
    
    modifier only_one_refund {
        require(bids[msg.sender].opened && !bids[msg.sender].refund); _;
        /// withdrawn => !opened
    }
    
    function debug_keccak(bytes32 nonce, uint val) public pure returns (bytes32) {
        return keccak256(abi.encode(nonce,val));
    }
    
    constructor (address payable _seller, uint _reserve_price, uint _commitment_phase_length, uint _withdrawal_phase_length, 
                    uint _opening_phase_length, uint _deposit_requirement, uint _escrow_duration, bool _debug) public {
        require(_deposit_requirement > 0);
        require(_reserve_price > 0);
        require(_deposit_requirement >= _reserve_price/4 && _deposit_requirement <= _reserve_price/2);

        seller = _seller;

        deposit_requirement  = _deposit_requirement;
        reserve_price = _reserve_price;

        commitment_phase_length = _commitment_phase_length;
        end_commitment = start+commitment_phase_length;
        
        withdrawal_phase_length = _withdrawal_phase_length;
        start_withdrawal = end_commitment+1;
        end_withdrawal = start_withdrawal+withdrawal_phase_length;
        
        opening_phase_length = _opening_phase_length;
        start_opening = end_withdrawal+1;
        end = start_opening+opening_phase_length;
        
        escrow_duration = _escrow_duration;
        debug = _debug;
        
        emit LogAuctionStarting(start, end);
    }
    
    function commit(bytes32 _envelope) public payable only_during(start, end_commitment) {
        require(msg.sender != seller && msg.sender != auctioneer);
        require(bids[msg.sender].bid_hash == "");
        require(msg.value == deposit_requirement);
        
        bids[msg.sender].bid_hash = _envelope;
        
        emit LogEnvelopeCommited(msg.sender);
        
    }
    
    function withdraw_envelope() public only_during(start_withdrawal, end_withdrawal) {
        require(bids[msg.sender].withdrawn == false);
        
        bids[msg.sender].withdrawn = true;
        emit LogEnvelopeWithdrawn(msg.sender);

        msg.sender.transfer(deposit_requirement/2);
        
    }
    
    function open(bytes32 nonce) public payable only_during(start_opening, end) {
        require(bids[msg.sender].bid_hash.length > 0 && !bids[msg.sender].opened && !bids[msg.sender].withdrawn);

        bytes32 hash = keccak256(abi.encode(nonce, msg.value));
        require(hash == bids[msg.sender].bid_hash);
        
        bids[msg.sender].opened = true;
        bids[msg.sender].value = msg.value;
        
        /// void bid 
        if(msg.value < reserve_price) {
            bids[msg.sender].refund = true;
            emit LogVoidBid(msg.sender, msg.value);
            msg.sender.transfer(msg.value+(deposit_requirement/2));
        } else {    
            /// first valid opened bid
            if(highest_bid == 0) {
                price_to_pay = reserve_price;
                highest_bid = msg.value;
                highest_bidder = msg.sender;
                emit LogHighestBid(msg.sender, msg.value, reserve_price);
            }
            /// losing bid
            else if(msg.value <= highest_bid ) {
               ///...but check if 2nd highest bid
                if(msg.value >= price_to_pay) {
                    emit LogUpdateSecondPrice(msg.value, price_to_pay);
                    price_to_pay = msg.value;
                }
                bids[msg.sender].refund = true;
                uint full_refund = msg.value+deposit_requirement;
                emit LogLosingBid(msg.sender, msg.value);
                msg.sender.transfer(full_refund);
            }
            /// new highest_bid
            else {
                price_to_pay = highest_bid;
                highest_bid = msg.value;
                highest_bidder = msg.sender;
                emit LogHighestBid(msg.sender, msg.value, price_to_pay);
            }
        }
    }
    
    function finalize() public only_when_closed only_auctioneer_seller_buyer returns (bool){
        require(!sold);
        if(highest_bid == 0) {
            emit LogUnsold();
            return false;
        }
        sold = true;
        /// initialize escrow contract
        Escrow e = (new Escrow).value(price_to_pay)(seller, highest_bidder, debug, 50);
        emit LogEscrowCreated(address(e));
        /// send fund to charity
        charity.transfer(address(this).balance);
        
        return true;
    }
    
    function ask_refund() public only_when_closed only_one_refund {
        bids[msg.sender].refund = true;
        
        uint refund;
        
        if(msg.sender == highest_bidder)
            refund = deposit_requirement+(highest_bid-price_to_pay);
        else
            refund = deposit_requirement+bids[msg.sender].value;
        
        
        msg.sender.transfer(refund);
    }
}