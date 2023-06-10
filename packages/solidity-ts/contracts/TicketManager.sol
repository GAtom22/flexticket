// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./EventTicket.sol";

// This contract manages the sale of tickets for an event using an NFT contract
// It inherits the Ownable contract to ensure that only the contract owner can call certain functions
contract TicketManager is Ownable {
  using SafeMath for uint256;
  // Public variables
  string public eventName; // The name of the event
  uint256 public eventId; // The event id
  uint256 public tierId; // The ticket tier id
  uint256 public basePrice; // The base price of each ticket
  uint256 public initialPrice; // The initial price of the ticket tier. Used for the getCurrentPrice equation that starts with a high initial price
  uint256 public priceSlope; // The slope of the decreasing pricing equation
  uint256 public yIntercept; // The y-intercept of the decreasing pricing equation
  address public nftAddress; // The address of the NFT contract (tickets)
  uint256 public totalTickets; // The total number of tickets available for sale
  uint256 public ticketsSold; // The number of tickets sold so far
  uint256 public totalRevenue; // The total revenue generated from ticket sales
  uint256 public startTime; // The start time of the ticket sale
  uint256 public endTime; // The end time of the ticket sale
  uint256 public discountPercentage; // The percentage discount applied to the base price of each ticket

  // Mapping to keep track of the number of tickets owned by each buyer
  mapping(address => mapping(address => uint256)) public ticketBalances;

  event TicketPurchased(address indexed buyer, uint256 eventId, uint256 tierId, uint256 price);
  event BasePriceChanged(uint256 eventId, uint256 tierId, uint256 price);
  event PriceChanged(uint256 eventId, uint256 tierId, uint256 price);

  constructor(
    string memory _eventName,
    uint256 _eventId,
    uint256 _tierId,
    string memory _baseURI,
    string memory _symbol,
    uint256 _basePrice,
    uint256 _initialPrice,
    uint256 _totalTickets,
    uint256 _startTime,
    uint256 _endTime
  ) {
    // Initialize public variables
    eventName = _eventName;
    eventId = _eventId;
    tierId = _tierId;
    basePrice = _basePrice;
    initialPrice = _initialPrice;
    totalTickets = _totalTickets;
    startTime = _startTime;
    endTime = _endTime;

    uint256 timeSpan = _endTime.sub(_startTime);
    priceSlope = basePrice.sub(initialPrice).div(timeSpan);
    yIntercept = initialPrice.sub(startTime.mul(priceSlope));

    // Create a new NFT contract for the event
    EventTicket nftContract = new EventTicket(string(abi.encodePacked(_eventName, " Ticket")), _symbol, _totalTickets, _baseURI);
    nftAddress = address(nftContract); // Set the address of the NFT contract
  }

  // Function to purchase a ticket
  function purchaseTicket() public payable {
    require(block.timestamp >= startTime, "Ticket sales have not started yet");
    require(block.timestamp <= endTime, "Ticket sales have ended");
    require(totalTickets > ticketsSold, "This event sold out!");

    uint256 price = getCurrentPrice();
    require(msg.value >= price, "Current ticket price is higher than the provided value");

    EventTicket nftContract = EventTicket(nftAddress);

    // Mint new ticket NFT and transfer ownership to the buyer
    nftContract.mint(msg.sender);

    // Update the ticket balance of the buyer
    ticketBalances[msg.sender][nftAddress]++;

    ticketsSold++;
    totalRevenue += msg.value;

    emit TicketPurchased(msg.sender, eventId, tierId, msg.value);
  }

  // Function to get the current price of a ticket based on market conditions
  function getCurrentPrice() public returns (uint256) {
    require(block.timestamp <= endTime, "Ticket sales ended");
    uint256 ticketsLeft = totalTickets.sub(ticketsSold);
    require(ticketsLeft > 0, "No more tickets left!");

    uint256 timeLeft = endTime.sub(block.timestamp).div(3600); // time left
    uint256 hoursLeft = timeLeft.div(3600); // time left in hours
    uint256 adjustedPrice;

    // Calculate the average number of tickets sold per hour
    uint256 hoursElapsed = block.timestamp.sub(startTime).div(3600);
    uint256 saleRate = 0;
    if (hoursElapsed > 0) {
      saleRate = ticketsSold.div(hoursElapsed);
    }

    // no sales rate, use base price
    if (saleRate == 0) {
      // gradually decrease the initialPrice
      // linear eq: price = time . slope + yInt
      adjustedPrice = yIntercept.add(block.timestamp.mul(priceSlope));

      emit PriceChanged(eventId, tierId, adjustedPrice);

      return adjustedPrice;
    }

    // Calculate the target sale rate based on the remaining time and inventory
    // Sell remaining tickets in half the remaining time
    if (hoursLeft == 0) {
      hoursLeft = 1;
    }
    uint256 targetSaleRate = ticketsLeft.mul(2).div(hoursLeft);

    // start at initial price
    // decrease if salesRate < targetRate
    // increase if salesRate > targetRate

    // Calculate the adjustment factor based on the difference
    // between the target and actual sale rates
    uint256 adjustmentFactor = saleRate.sub(targetSaleRate).mul(100).div(targetSaleRate);

    uint256 price = yIntercept.add(block.timestamp.mul(priceSlope));

    //Apply the adjustment factor to the base price
    adjustedPrice = price.add(adjustmentFactor);

    // price cannot be lower than basePrice
    if (adjustedPrice < basePrice) {
      adjustedPrice = basePrice;
    } else {
      // update the y-intercept and slope
      priceSlope = basePrice.sub(adjustedPrice).div(timeLeft);
      yIntercept = adjustedPrice.sub(block.timestamp.mul(priceSlope));
    }

    emit PriceChanged(eventId, tierId, adjustedPrice);

    return adjustedPrice;
  }

  // updateBasePrice function allows the contract owner to update the base ticket price for the event
  function updateBasePrice(uint256 newPrice) public onlyOwner {
    basePrice = newPrice;

    // update price decline line
    uint256 timeSpan = endTime.sub(block.timestamp);
    priceSlope = basePrice.sub(initialPrice).div(timeSpan);
    yIntercept = initialPrice.sub(startTime.mul(priceSlope));

    emit BasePriceChanged(eventId, tierId, newPrice);
  }

  // updateTicketURI function allows the contract owner to update the base URI for
  // the NFTs that represent the event tickets.
  // The new URI is passed as an argument and is then passed on to the updateBaseURI function of the EventTicket contract
  function updateTicketURI(string memory _newURI) public onlyOwner {
    EventTicket nftContract = EventTicket(nftAddress);
    nftContract.updateBaseURI(_newURI);
  }

  // setDiscount function allows the contract owner to set a discount percentage for the ticket price
  function setDiscount(uint256 percentage) public onlyOwner {
    require(discountPercentage == 0, "Need to cancel the current discount to set a new discount rate");
    require(percentage < 100, "Discount should be less than 100%, otherwise is not a discount");
    require(percentage > 0, "Discount should be a positive number between 0 and 99");
    discountPercentage = percentage;
    basePrice = (basePrice * (100 - percentage)) / 100;
  }

  // cancelDiscount function allows the contract owner to cancel any previously set discount
  function cancelDiscount() public onlyOwner {
    require(discountPercentage > 0, "There's no discount to cancel");
    basePrice = (basePrice * 100) / (100 - discountPercentage);
    discountPercentage = 0;
  }

  // withdraw function allows the contract owner to withdraw the total revenue earned from ticket sales once the event has ended.
  function withdraw() public onlyOwner {
    // if no tickets left, then allow to withdraw and update endTime
    uint256 ticketsLeft = totalTickets.sub(ticketsSold);
    if (ticketsLeft == 0) {
      endTime = block.timestamp;
    }
    require(block.timestamp > endTime, "Ticket sales still active");
    (bool sent, ) = owner().call{ value: totalRevenue }("");
    require(sent, "Failed to withdraw the revenue");
  }
}
