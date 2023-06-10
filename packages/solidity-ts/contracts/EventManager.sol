// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TicketManager.sol";

contract EventManager {
  // Fee used to charge the organizer if registering the event
  // paying a one-time fixed fee
  uint256 public fee = 0.25 ether;

  struct Event {
    address owner;
    string name;
    string description;
    uint256 startDate;
    uint256 endDate;
    TicketTier[] ticketTiers;
  }

  struct TicketTier {
    string _tierName;
    string _baseURI;
    string _symbol;
    uint256 _initialPrice;
    uint256 _basePrice;
    uint256 _totalTickets;
  }

  Event[] private events;

  // Map of the ticket managers per event per tier
  // map[eventID] -> map[tier] -> ticketManager address
  mapping(uint256 => mapping(uint256 => address)) private ticketManagers;

  modifier validEventAndTier(uint256 _eventId, uint256 _ticketTier) {
    require(_eventId < events.length, "Invalid event ID");
    require(ticketManagers[_eventId][_ticketTier] != address(0), "Ticket tier for this event does not exist");
    _;
  }

  function registerEventWithFixedFee(
    string memory _name,
    string memory _description,
    uint256 _startDate,
    uint256 _endDate,
    TicketTier[] memory _ticketTiers
  ) public payable {
    require(_startDate >= block.timestamp, "Event start date must be in the future");
    require(msg.value >= fee, "Insufficient fee");

    Event memory newEvent = Event({
      owner: msg.sender,
      name: _name,
      description: _description,
      startDate: _startDate,
      endDate: _endDate,
      ticketTiers: _ticketTiers
    });

    events.push(newEvent);
  }

  function registerEventWithFeePerTicketSold(
    string memory _name,
    string memory _description,
    uint256 _startDate,
    uint256 _endDate,
    TicketTier[] memory _ticketTiers
  ) public {
    require(_startDate >= block.timestamp, "Event start date must be in the future");

    // TODO add the custom logic for this type of registration
    Event memory newEvent = Event({
      owner: msg.sender,
      name: _name,
      description: _description,
      startDate: _startDate,
      endDate: _endDate,
      ticketTiers: _ticketTiers
    });

    events.push(newEvent);
  }

  function getEventDetails(uint256 _eventId) public view returns (Event memory) {
    require(_eventId < events.length, "Invalid event ID");

    Event memory e = events[_eventId];
    return e;
  }

  function launchEvent(uint256 _eventId) public {
    require(_eventId < events.length, "Invalid event ID");
    Event memory e = events[_eventId];
    require(e.ticketTiers.length > 0, "Events has no ticket tiers");

    // deploy a TicketManager for each tier
    // and store on the ticketManagers mapping
    TicketTier[] memory ticketTiers = e.ticketTiers;
    for (uint256 i = 0; i < ticketTiers.length; i++) {
      TicketTier memory tier = ticketTiers[i];
      TicketManager ticketManager = new TicketManager(
        e.name,
        _eventId,
        i,  // tierId
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
    require(_eventId < events.length, "Invalid event ID");
    TicketTier[] memory ticketTiers = events[_eventId].ticketTiers;

    for (uint256 i = 0; i < ticketTiers.length; i++) {
      if (ticketManagers[_eventId][i] != address(0)) {
        TicketManager ticketManager = TicketManager(ticketManagers[_eventId][i]);
        ticketManager.withdraw();
      }
    }
  }
}
