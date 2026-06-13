// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EventTicketNFT is ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    
    Counters.Counter private _tokenIdCounter;
    
    struct Ticket {
        uint256 eventId;
        uint256 price;
        address originalBuyer;
        uint256 purchaseTime;
        bool isVIP;
        string seatNumber;
        bool isRefunded;
        uint256 governanceWeight; // Voting power for ticket holders
    }
    
    struct Event {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 maxSupply;
        uint256 priceETH;
        address paymentToken;
        uint256 priceToken;
        uint256 ticketsSold;
        bool isActive;
    }
    
    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => Event) public events;
    mapping(uint256 => mapping(address => uint256)) public ticketsPerWallet;
    mapping(uint256 => uint256) public eventCounter;
    
    uint256 public currentEventId;
    uint256 public daoFeePercentage = 5; // 5% goes to DAO treasury
    
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address indexed buyer);
    event EventCreated(uint256 indexed eventId, string name, uint256 maxSupply);
    event TicketRefunded(uint256 indexed tokenId, address indexed owner);
    event GovernanceWeightUpdated(uint256 indexed tokenId, uint256 weight);
    
    constructor() ERC721("DAO Event Ticket", "DAOTKT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        currentEventId = 0;
    }
    
    /**
     * @dev Create new event (DAO governance only)
     */
    function createEvent(
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxSupply,
        uint256 priceETH,
        address paymentToken,
        uint256 priceToken
    ) external onlyRole(GOVERNOR_ROLE) returns (uint256) {
        require(endTime > startTime, "Invalid time range");
        require(maxSupply > 0, "Invalid supply");
        
        currentEventId++;
        events[currentEventId] = Event({
            name: name,
            startTime: startTime,
            endTime: endTime,
            maxSupply: maxSupply,
            priceETH: priceETH,
            paymentToken: paymentToken,
            priceToken: priceToken,
            ticketsSold: 0,
            isActive: true
        });
        
        emit EventCreated(currentEventId, name, maxSupply);
        return currentEventId;
    }
    
    /**
     * @dev Mint ticket with ETH (DAO members get governance weight)
     */
    function mintTicket(uint256 eventId, bool isVIP, string memory seatNumber) external payable {
        Event storage eventData = events[eventId];
        require(eventData.isActive, "Event not active");
        require(block.timestamp >= eventData.startTime, "Event not started");
        require(block.timestamp <= eventData.endTime, "Event ended");
        require(eventData.ticketsSold < eventData.maxSupply, "Sold out");
        require(ticketsPerWallet[eventId][msg.sender] < 5, "Wallet limit reached");
        require(msg.value >= eventData.priceETH, "Insufficient ETH");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Calculate governance weight (VIP tickets get more voting power)
        uint256 governanceWeight = isVIP ? 100 : 10;
        
        tickets[tokenId] = Ticket({
            eventId: eventId,
            price: eventData.priceETH,
            originalBuyer: msg.sender,
            purchaseTime: block.timestamp,
            isVIP: isVIP,
            seatNumber: seatNumber,
            isRefunded: false,
            governanceWeight: governanceWeight
        });
        
        ticketsPerWallet[eventId][msg.sender]++;
        eventData.ticketsSold++;
        
        _safeMint(msg.sender, tokenId);
        
        // DAO fee
        uint256 daoFee = (msg.value * daoFeePercentage) / 100;
        uint256 eventFee = msg.value - daoFee;
        
        // Send fees to appropriate addresses
        payable(address(this)).transfer(daoFee); // DAO treasury claimable
        
        emit TicketMinted(tokenId, eventId, msg.sender);
        emit GovernanceWeightUpdated(tokenId, governanceWeight);
        
        // Refund excess
        if (msg.value > eventData.priceETH) {
            payable(msg.sender).transfer(msg.value - eventData.priceETH);
        }
    }
    
    /**
     * @dev Get governance weight for ticket holder
     */
    function getVotingPower(address holder) external view returns (uint256) {
        uint256 totalWeight = 0;
        uint256 balance = balanceOf(holder);
        
        // This would need to iterate through tokens - simplified for gas
        // In production, use enumerable or separate tracking
        return balance * 10; // Placeholder - 10 weight per ticket
    }
    
    /**
     * @dev Refund ticket (before event starts)
     */
    function refundTicket(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        Ticket storage ticket = tickets[tokenId];
        require(!ticket.isRefunded, "Already refunded");
        require(block.timestamp < events[ticket.eventId].startTime, "Event started");
        
        ticket.isRefunded = true;
        _burn(tokenId);
        
        ticketsPerWallet[ticket.eventId][msg.sender]--;
        events[ticket.eventId].ticketsSold--;
        
        payable(msg.sender).transfer(ticket.price);
        
        emit TicketRefunded(tokenId, msg.sender);
    }
    
    /**
     * @dev Withdraw DAO fees
     */
    function withdrawDAOFees() external onlyRole(GOVERNOR_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        payable(msg.sender).transfer(balance);
    }
    
    /**
     * @dev Update DAO fee percentage
     */
    function updateDAOFee(uint256 newPercentage) external onlyRole(GOVERNOR_ROLE) {
        require(newPercentage <= 20, "Fee too high");
        daoFeePercentage = newPercentage;
    }
    
    /**
     * @dev Get ticket details
     */
    function getTicketDetails(uint256 tokenId) external view returns (
        uint256 eventId,
        uint256 price,
        address buyer,
        uint256 purchaseTime,
        bool isVIP,
        string memory seatNumber,
        uint256 governanceWeight
    ) {
        Ticket memory ticket = tickets[tokenId];
        return (
            ticket.eventId,
            ticket.price,
            ticket.originalBuyer,
            ticket.purchaseTime,
            ticket.isVIP,
            ticket.seatNumber,
            ticket.governanceWeight
        );
    }
    
    /**
     * @dev Get event details
     */
    function getEventDetails(uint256 eventId) external view returns (
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxSupply,
        uint256 ticketsSold,
        bool isActive
    ) {
        Event memory eventData = events[eventId];
        return (
            eventData.name,
            eventData.startTime,
            eventData.endTime,
            eventData.maxSupply,
            eventData.ticketsSold,
            eventData.isActive
        );
    }
    
    // Required overrides
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}