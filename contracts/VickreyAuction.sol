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
    uint reserve_price;
    uint commitment_phase_length;
    uint withdrawal_phase_length;
    uint opening_phase_length;
    uint deposit_requirement;
    
    uint start = block.number + 20; /// 20 is a grace period of about 5 mins
    uint end_commitment;
    
    uint start_withdrawal;
    uint end_withdrawal;
    
    uint start_opening;
    uint end;
    
    /// state of the contract
    mapping(address => Bid) public bids;

    address highest_bidder;
    uint highest_bid;
    uint price_to_pay; /// 2nd highest bid
    
    uint total_bid; /// total envelopes received
    uint total_opened; /// total envelopes opened
    uint total_withdrawn; /// total envelopes withdrawn
    uint total_void; /// total envelopes opened but with bid < reserve_price
    
    bool sold;

    event AuctionStarting(uint, uint);
    
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
    
    constructor (address payable _seller, uint _reserve_price, uint _commitment_phase_length, uint _withdrawal_phase_length, uint _opening_phase_length, uint _deposit_requirement) public {
        require(deposit_requirement > 0);
        require(reserve_price > 0);
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
        
        
        emit AuctionStarting(start, end);
    }
    
    function commit(bytes32 _envelope) public payable only_during(start, end_commitment) {
        require(msg.sender != seller && msg.sender != auctioneer);
        require(bids[msg.sender].bid_hash == "");
        require(msg.value == deposit_requirement);
        
        bids[msg.sender].bid_hash = _envelope;

        total_bid++;
        
    }
    
    function withdraw_envelope() public only_during(start_withdrawal, end_withdrawal) {
        require(bids[msg.sender].withdrawn == false);
        
        bids[msg.sender].withdrawn = true;
        total_withdrawn++;
        msg.sender.transfer(deposit_requirement/2);
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
            msg.sender.transfer(msg.value+(deposit_requirement/2));
        } else {
            total_opened++;
    
            /// first valid opened bid
            if(total_opened == 1) {
                price_to_pay = reserve_price;
                highest_bid = msg.value;
                highest_bidder = msg.sender;
            }
            /// losing bid
            else if(msg.value <= highest_bid ) {
               ///...but check if 2nd highest bid
                if(msg.value >= price_to_pay)
                    price_to_pay = msg.value;
                               
                bids[msg.sender].refund = true;
                uint full_refund = msg.value+deposit_requirement;
                msg.sender.transfer(full_refund);
            }
            /// new highest_bid
            else {
                price_to_pay = highest_bid;
                highest_bid = msg.value;
                highest_bidder = msg.sender;
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