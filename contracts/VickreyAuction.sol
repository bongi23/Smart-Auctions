pragma solidity >=0.4.21 <0.6.0;

contract VickreyAuction {
    
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
    
    uint public start = block.number; /// 20 is a grace period of about 5 mins
    uint public end_commitment;
    
    uint public start_withdrawal;
    uint public end_withdrawal;
    
    uint public start_opening;
    uint public end;
    
    /// state of the contract
    mapping(address => Bid) public bids;

    address public highest_bidder;
    uint public highest_bid;
    uint public price_to_pay; /// 2nd highest bid
    
    uint public total_bid; /// total envelopes received
    uint public total_opened; /// total envelopes opened
    uint public total_withdrawn; /// total envelopes withdrawn
    uint public total_void; /// total envelopes opened but with bid < reserve_price
    
    bool public sold;

    event LogAuctionStarting(uint, uint);
    event LogEnvelopeCommited(address);
    event LogEnvelopeWithdrawn(address);
    event LogVoidBid(address, uint);
    event LogLosingBid(address, uint);
    event LogHighestBid(address, uint, uint);
    event LogUpdateSecondPrice(uint, uint);
    
    
    modifier only_during(uint start_block, uint end_block) {
        require(block.number >= start && block.number <= end); _;
    }
    
    modifier only_when_closed {
        require(block.number > end); _;
    }
    
    modifier only_auctioneer {
        require(msg.sender == auctioneer); _;
    }
    
    modifier only_one_refund {
        require(bids[msg.sender].opened && !bids[msg.sender].refund); _;
        /// withdrawn => !opened
    }
    
    function debug_keccak(bytes32 nonce, uint val) public pure returns (bytes32) {
        return keccak256(abi.encode(nonce,val));
    }
    
    constructor (address payable _seller, uint _reserve_price, uint _commitment_phase_length, uint _withdrawal_phase_length, uint _opening_phase_length, uint _deposit_requirement) public {
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
        
        
        emit LogAuctionStarting(start, end);
    }
    
    function commit(bytes32 _envelope) public payable only_during(start, end_commitment) {
        require(msg.sender != seller && msg.sender != auctioneer);
        require(bids[msg.sender].bid_hash == "");
        require(msg.value == deposit_requirement);
        
        bids[msg.sender].bid_hash = _envelope;

        total_bid++;
        
        emit LogEnvelopeCommited(msg.sender);
        
    }
    
    function withdraw_envelope() public only_during(start_withdrawal, end_withdrawal) {
        require(bids[msg.sender].withdrawn == false);
        
        bids[msg.sender].withdrawn = true;
        total_withdrawn++;
        msg.sender.transfer(deposit_requirement/2);
        
        emit LogEnvelopeWithdrawn(msg.sender);
    }
    
    function open(bytes32 nonce) public payable only_during(start_opening, end) {
        require(bids[msg.sender].bid_hash != "" && !bids[msg.sender].opened && !bids[msg.sender].withdrawn);

        bytes32 hash = keccak256(abi.encode(nonce, msg.value));
        require(hash == bids[msg.sender].bid_hash);
        
        bids[msg.sender].opened = true;
        bids[msg.sender].value = msg.value;
        
        /// void bid 
        if(msg.value < reserve_price) {
            bids[msg.sender].refund = true;
            total_void++;
            emit LogVoidBid(msg.sender, msg.value);
            msg.sender.transfer(msg.value+(deposit_requirement/2));
        } else {
            total_opened++;
    
            /// first valid opened bid
            if(total_opened == 1) {
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
    
    function finalize() public only_when_closed only_auctioneer{
        require(!sold);
        sold = true;
        
        uint total_closed = total_bid - (total_opened+total_withdrawn+total_void);
        uint charity_funds = total_closed*deposit_requirement + (total_withdrawn+total_void)*deposit_requirement/2;
        
        /// pay seller
        seller.transfer(price_to_pay);
        /// send fund to charity
        charity.transfer(charity_funds);
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