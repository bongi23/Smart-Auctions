pragma solidity >=0.4.21 <0.6.0;

contract Auction {
    uint reserve_price;
    uint start;
    uint end;

    address highest_bidder;
    uint highest_bid;
    
    event LogAuctionStarting(uint, uint);
    event LogHighestBid(address, uint, uint);

    bool debug;

}