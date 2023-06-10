// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TicketManager.sol";

contract EventManager {
  uint256 public fee = 0.25 ether;

  struct Event {
    address owner;
    string name;
    string description;
    uint256 startDate;
    uint256 endDate;
    uint256[] ticketTiers;
  }

  Event[] private events;

  // Map of the ticket managers per event per tier
  // map[eventID] -> map[tier] -> ticketManager address
  mapping(uint256 => mapping(uint256 => address)) private ticketManagers;

  function registerEventWithFixedFee(
    string memory _name,
    string memory _description,
    uint256 _startDate,
    uint256 _endDate,
    uint256[] memory _ticketTiers
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
    uint256[] memory _ticketTiers
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

  function getEventDetails(uint256 _eventId)
    public
    view
    returns (
      string memory,
      string memory,
      uint256,
      uint256,
      uint256[] memory
    )
  {
    require(_eventId < events.length, "Invalid event ID");

    Event memory e = events[_eventId];

    return (e.name, e.description, e.startDate, e.endDate, e.ticketTiers);
  }

  function launchEvent(uint256 _eventId, uint256[] memory _ticketPrices) public {
    require(_eventId < events.length, "Invalid event ID");
    Event memory e = events[_eventId];
    require(_ticketPrices.length == e.ticketTiers.length, "Invalid event ID");

    // TODO deploy a TicketManager for each tier
    // and store on the ticketManagers mapping
  }

  function getTicketPrice(uint256 _eventId, uint256 _ticketTier) public view returns (uint256) {
    require(_eventId < events.length, "Invalid event ID");
    require(ticketManagers[_eventId][_ticketTier] != address(0), "Ticket tier for this event does not exist");

    // TODO call corresponding method on ticketManager contract
  }

  function buyTicket(uint256 _eventId, uint256 _ticketTier) public payable {
    // TODO call corresponding method on ticketManager contract
  }

  function updateBasePrice(
    uint256 _eventId,
    uint256 _ticketTier,
    uint256 newPrice
  ) public {
    // TODO call corresponding method on ticketManager contract
  }

  function updateTicketURI(
    uint256 _eventId,
    uint256 _ticketTier,
    string memory _newURI
  ) public {
    // TODO call corresponding method on ticketManager contract
  }

  function setDiscount(
    uint256 _eventId,
    uint256 _ticketTier,
    uint256 percentage
  ) public {
    // TODO call corresponding method on ticketManager contract
  }

  function cancelDiscount(uint256 _eventId, uint256 _ticketTier) public {
    // TODO call corresponding method on ticketManager contract
  }

  function withdrawByTier(uint256 _eventId, uint256 _ticketTier) public {
    // TODO call corresponding method on ticketManager contract
  }

  function withdrawAll(uint256 _eventId) public {
    // TODO call corresponding method on ticketManager contract
  }
}
