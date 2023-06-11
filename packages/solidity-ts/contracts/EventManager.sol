// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TicketManager.sol";

contract EventManager {
  // Fee used to charge the organizer if registering the event
  // paying a one-time fixed fee
  uint256 public fee = 0.001 ether;

  struct Event {
    address owner;
    string name;
    string description;
    uint256 startDate;
    uint256 endDate;
  }

  struct TicketTier {
    string _tierName;
    string _baseURI;
    string _symbol;
    uint256 _initialPrice;
    uint256 _basePrice;
    uint256 _totalTickets;
  }

  event CreatedEvent(address indexed organizer, uint256 eventId);

  Event[] public events;
  uint256 public eventsCount;

  // Map of ticket tiers per eventId
  mapping(uint256 => TicketTier[]) public ticketTiers;
  // Map of the ticket managers per event per tier
  // map[eventID] -> map[tier] -> ticketManager address
  mapping(uint256 => mapping(uint256 => address)) public ticketManagers;

  modifier validEventAndTier(uint256 _eventId, uint256 _ticketTier) {
    require(_eventId < eventsCount, "Invalid ID");
    require(ticketManagers[_eventId][_ticketTier] != address(0), "tier does not exist");
    _;
  }

  function registerEventWithFixedFee(
    string memory _name,
    string memory _description,
    uint256 _startDate,
    uint256 _endDate,
    TicketTier[] memory _ticketTiers
  ) public payable returns (uint256) {
    require(_startDate >= block.timestamp, "start date must be in the future");
    require(_ticketTiers.length > 0, "Provide at least one tier");
    require(msg.value >= fee, "Insufficient fee");

    Event memory newEvent = Event({ owner: msg.sender, name: _name, description: _description, startDate: _startDate, endDate: _endDate });

    events.push(newEvent);
    eventsCount++;

    uint256 eventId = eventsCount - 1;
    // Copy the elements from memory to storage
    for (uint256 i = 0; i < _ticketTiers.length; i++) {
      ticketTiers[eventId].push(_ticketTiers[i]);
    }

    launchEvent(eventId);

    emit CreatedEvent(msg.sender, eventId);

    return eventId;
  }

  function launchEvent(uint256 _eventId) public {
    require(_eventId < eventsCount, "Invalid ID");

    Event memory e = events[_eventId];
    require(msg.sender == e.owner, "launch not allowed");

    // deploy a TicketManager for each tier
    // and store on the ticketManagers mapping
    TicketTier[] memory tiers = ticketTiers[_eventId];
    require(tiers.length > 0, "no tiers");

    for (uint256 i = 0; i < tiers.length; i++) {
      TicketTier memory tier = tiers[i];
      TicketManager ticketManager = new TicketManager(
        e.name,
        _eventId,
        i, // tierId
        tier._baseURI,
        tier._symbol,
        tier._basePrice,
        tier._initialPrice,
        tier._totalTickets,
        e.startDate,
        e.endDate
      );
      ticketManagers[_eventId][i] = address(ticketManager);
    }
  }

  function getTicketPrice(uint256 _eventId, uint256 _ticketTier) public validEventAndTier(_eventId, _ticketTier) returns (uint256) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    return ticketManager.getCurrentPrice();
  }

  function getAllEvents() public view returns (Event[] memory) {
    return events;
  }

  function getTiersByEventId(uint256 _eventId) public view returns (TicketTier[] memory) {
    return ticketTiers[_eventId];
  }

  function buyTicket(uint256 _eventId, uint256 _ticketTier) public payable validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.purchaseTicket{ value: msg.value }();
  }

  function updateBasePrice(uint256 _eventId, uint256 _ticketTier, uint256 newPrice) public validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.updateBasePrice(newPrice);
  }

  function updateTicketURI(uint256 _eventId, uint256 _ticketTier, string memory _newURI) public validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.updateTicketURI(_newURI);
  }

  function setDiscount(uint256 _eventId, uint256 _ticketTier, uint256 percentage) public validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.setDiscount(percentage);
  }

  function cancelDiscount(uint256 _eventId, uint256 _ticketTier) public validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.cancelDiscount();
  }

  function withdrawByTier(uint256 _eventId, uint256 _ticketTier) public validEventAndTier(_eventId, _ticketTier) {
    TicketManager ticketManager = TicketManager(ticketManagers[_eventId][_ticketTier]);
    ticketManager.withdraw();
  }

  function withdrawAll(uint256 _eventId) public {
    require(_eventId < eventsCount, "Invalid ID");
    TicketTier[] memory tiers = ticketTiers[_eventId];

    Event memory e = events[_eventId];
    require(msg.sender == e.owner, "not allowed to withdraw");

    for (uint256 i = 0; i < tiers.length; i++) {
      if (ticketManagers[_eventId][i] != address(0)) {
        TicketManager ticketManager = TicketManager(ticketManagers[_eventId][i]);
        ticketManager.withdraw();
      }
    }
  }

  function getPurchasedTickets() public view returns (TicketMeta[] memory) {
    TicketMeta[] memory tickets = new TicketMeta[](eventsCount);
    uint256 index;
    for (uint256 eventId = 0; eventId < eventsCount; eventId++) {
      TicketTier[] memory tiers = ticketTiers[eventId];
      for (uint256 i = 0; i < tiers.length; i++) {
        if (ticketManagers[eventId][i] != address(0)) {
          TicketManager ticketManager = TicketManager(ticketManagers[eventId][i]);
          TicketMeta memory ticket = ticketManager.getTickets();
          tickets[index] = ticket;
          index++;
        }
      }
    }
    return tickets;
  }
}
