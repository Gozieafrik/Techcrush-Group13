// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EventTicketNFT is ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant EVENT_MANAGER_ROLE = keccak256("EVENT_MANAGER_ROLE");
    
    Counters.Counter private _tokenIdCounter;
    
    struct Event {
        string name;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 maxSupply;
        uint256 mintedCount;
        uint256 price;
        bool isActive;
        string metadataURI;
        address organizer;
    }
    
    struct Ticket {
        uint256 eventId;
        uint256 seatNumber;
        bool isCheckedIn;
        uint256 purchaseTime;
        bool isTransferred;
    }
    
    mapping(uint256 => Event) public events;
    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => uint256) public tokenToEvent;
    mapping(address => uint256[]) public userTickets;
    
    uint256 public eventCounter;
    uint256 public royaltyPercentage = 5; // 5% royalty
    address public royaltyReceiver;
    
    event EventCreated(uint256 indexed eventId, string name, address organizer);
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address owner);
    event TicketCheckedIn(uint256 indexed tokenId, uint256 indexed eventId);
    event RoyaltyPaid(uint256 amount, address to);
    
    constructor() ERC721("EventTicketNFT", "ETNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(EVENT_MANAGER_ROLE, msg.sender);
        royaltyReceiver = msg.sender;
    }
    
    function createEvent(
        string memory name,
        string memory venue,
        uint256 startTime,
        uint256 endTime,
        uint256 maxSupply,
        uint256 price,
        string memory metadataURI
    ) external onlyRole(EVENT_MANAGER_ROLE) returns (uint256) {
        require(startTime > block.timestamp, "Start time must be in future");
        require(endTime > startTime, "End time must be after start time");
        require(maxSupply > 0, "Max supply must be positive");
        
        eventCounter++;
        events[eventCounter] = Event({
            name: name,
            venue: venue,
            startTime: startTime,
            endTime: endTime,
            maxSupply: maxSupply,
            mintedCount: 0,
            price: price,
            isActive: true,
            metadataURI: metadataURI,
            organizer: msg.sender
        });
        
        emit EventCreated(eventCounter, name, msg.sender);
        return eventCounter;
    }
    
    function mintTicket(uint256 eventId, uint256 seatNumber) external payable {
        Event storage eventInfo = events[eventId];
        require(eventInfo.isActive, "Event is not active");
        require(eventInfo.mintedCount < eventInfo.maxSupply, "Event sold out");
        require(block.timestamp < eventInfo.startTime, "Event already started");
        require(msg.value >= eventInfo.price, "Insufficient payment");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        
        tickets[tokenId] = Ticket({
            eventId: eventId,
            seatNumber: seatNumber,
            isCheckedIn: false,
            purchaseTime: block.timestamp,
            isTransferred: false
        });
        
        tokenToEvent[tokenId] = eventId;
        userTickets[msg.sender].push(tokenId);
        eventInfo.mintedCount++;
        
        // Handle payment and royalty
        uint256 royalty = (msg.value * royaltyPercentage) / 100;
        uint256 organizerShare = msg.value - royalty;
        
        payable(royaltyReceiver).transfer(royalty);
        payable(eventInfo.organizer).transfer(organizerShare);
        
        emit RoyaltyPaid(royalty, royaltyReceiver);
        emit TicketMinted(tokenId, eventId, msg.sender);
    }
    
    function checkIn(uint256 tokenId) external {
        require(hasRole(EVENT_MANAGER_ROLE, msg.sender), "Not authorized");
        Ticket storage ticket = tickets[tokenId];
        require(!ticket.isCheckedIn, "Already checked in");
        require(block.timestamp <= events[ticket.eventId].endTime, "Event ended");
        
        ticket.isCheckedIn = true;
        emit TicketCheckedIn(tokenId, ticket.eventId);
    }
    
    function transferTicket(uint256 tokenId, address to) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        Ticket storage ticket = tickets[tokenId];
        require(!ticket.isTransferred, "Ticket already transferred");
        require(block.timestamp < events[ticket.eventId].startTime, "Event already started");
        
        safeTransferFrom(msg.sender, to, tokenId);
        ticket.isTransferred = true;
    }
    
    function getEventDetails(uint256 eventId) external view returns (
        string memory name,
        string memory venue,
        uint256 startTime,
        uint256 endTime,
        uint256 availableTickets,
        uint256 price
    ) {
        Event storage eventInfo = events[eventId];
        return (
            eventInfo.name,
            eventInfo.venue,
            eventInfo.startTime,
            eventInfo.endTime,
            eventInfo.maxSupply - eventInfo.mintedCount,
            eventInfo.price
        );
    }
    
    function getUserTickets(address user) external view returns (uint256[] memory) {
        return userTickets[user];
    }
    
    function getTicketInfo(uint256 tokenId) external view returns (
        uint256 eventId,
        uint256 seatNumber,
        bool isCheckedIn,
        uint256 purchaseTime,
        bool isTransferred
    ) {
        Ticket storage ticket = tickets[tokenId];
        return (
            ticket.eventId,
            ticket.seatNumber,
            ticket.isCheckedIn,
            ticket.purchaseTime,
            ticket.isTransferred
        );
    }
    
    function setRoyaltyPercentage(uint256 percentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(percentage <= 10, "Royalty too high");
        royaltyPercentage = percentage;
    }
    
    function setRoyaltyReceiver(address receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(receiver != address(0), "Invalid address");
        royaltyReceiver = receiver;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        uint256 eventId = tokenToEvent[tokenId];
        Event storage eventInfo = events[eventId];
        
        string memory json = string(
            abi.encodePacked(
                '{"name": "', eventInfo.name, ' Ticket",',
                '"description": "NFT Ticket for ', eventInfo.name, ' at ', eventInfo.venue, '",',
                '"image": "', eventInfo.metadataURI, '",',
                '"attributes": [',
                '{"trait_type": "Event", "value": "', eventInfo.name, '"},',
                '{"trait_type": "Venue", "value": "', eventInfo.venue, '"},',
                '{"trait_type": "Seat", "value": "', tickets[tokenId].seatNumber.toString(), '"}',
                ']}'
            )
        );
        
        return string(abi.encodePacked("data:application/json;base64,", 
            Base64.encode(bytes(json))));
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        
        string memory table = string(TABLE);
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLen + 32);
        
        uint256 pointer;
        assembly {
            pointer := add(result, 32)
        }
        
        uint256 i;
        uint256 j = 0;
        
        for (i = 0; i + 2 < data.length; i += 3) {
            (uint256 a, uint256 b, uint256 c) = (uint256(uint8(data[i])), uint256(uint8(data[i + 1])), uint256(uint8(data[i + 2])));
            uint256 n = (a << 16) | (b << 8) | c;
            
            result[j++] = bytes(table)[n >> 18 & 0x3F];
            result[j++] = bytes(table)[n >> 12 & 0x3F];
            result[j++] = bytes(table)[n >> 6 & 0x3F];
            result[j++] = bytes(table)[n & 0x3F];
        }
        
        if (i + 1 == data.length) {
            uint256 a = uint256(uint8(data[i]));
            uint256 n = (a << 16);
            
            result[j++] = bytes(table)[n >> 18 & 0x3F];
            result[j++] = bytes(table)[n >> 12 & 0x3F];
            result[j++] = bytes(table)[(n >> 6) & 0x3F];
        } else if (i + 2 == data.length) {
            uint256 a = uint256(uint8(data[i]));
            uint256 b = uint256(uint8(data[i + 1]));
            uint256 n = (a << 16) | (b << 8);
            
            result[j++] = bytes(table)[n >> 18 & 0x3F];
            result[j++] = bytes(table)[n >> 12 & 0x3F];
            result[j++] = bytes(table)[n >> 6 & 0x3F];
        }
        
        return string(result);
    }
}