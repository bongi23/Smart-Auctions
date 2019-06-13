pragma solidity >=0.4.21 <0.6.0;

contract Auction {
    uint reserve_price;
    uint start;
    uint end;

    address payable highest_bidder;
    uint highest_bid;
    
    event LogAuctionStarting(uint, uint);
    event LogHighestBid(address, uint, uint);
    event LogUnsold();
    event LogSold(address, uint);
    event LogEscrowCreated(address);

    bool debug;

}