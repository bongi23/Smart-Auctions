pragma solidity >=0.4.22 <0.7.0;

contract Auction {

    uint public reservePrice;

    address payable seller;
    address payable auctioneer = msg.sender;
    
    address payable highestBidder;
    uint public highestBid;
    
    event LogPhaseTransition(string);
    event LogAuctionStarting(uint, uint);
    event LogHighestBid(address, uint, uint);
    event LogUnsold();
    event LogSold(address, uint);
    event LogEscrowCreated(address);

    bool debug;
    
    modifier costs(uint cost) {
        require(msg.value == cost); _;
    }
    
     modifier onlyDebugging() {
        require(debug, "Function allowed only during debug"); _;
    }
    
     modifier notTheSeller() {
        require(seller != msg.sender, "Seller cannot commit a bid"); _;
    }
    
    modifier notTheAuctioneer() {
        require(auctioneer != msg.sender, "Auctioneer cannot commit a bid"); _;
    }

}