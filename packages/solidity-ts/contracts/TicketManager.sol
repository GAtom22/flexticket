// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./EventTicket.sol";

struct TicketMeta {
  string eventName;
  uint256 tierId;
  string symbol;
  uint256 count;
  address nftContractAddress;
}

// This contract manages the sale of tickets for an event using an NFT contract
// It inherits the Ownable contract to ensure that only the contract owner can call certain functions
contract TicketManager is Ownable {
  using SafeMath for uint256;
  // Public variables
  string public eventName; // The name of the event
  string public symbol; // The symbol for the NFT related to the tier
  uint256 public eventId; // The event id
  uint256 public tierId; // The ticket tier id
  uint256 public basePrice; // The base price of each ticket
  uint256 public initialPrice; // The initial price of the ticket tier. Used for the getCurrentPrice equation that starts with a high initial price
  uint256 public currentPrice; // The current price of the ticket tier
  uint256 public lastPriceUpdate; // The timestamp of the last price update
  uint256 public priceUpdateInterval; // The time interval to update the price
  uint256 public decayPercentage; // The percentage of the price range to consider for decreasing the price when no sales
  uint256 public salesTimeInterval; // The time interval to consider for calculating sales rates (ex. hours, minutes, days)
  address public nftAddress; // The address of the NFT contract (tickets)
  uint256 public totalTickets; // The total number of tickets available for sale
  uint256 public ticketsSold; // The number of tickets sold so far
  uint256 public totalRevenue; // The total revenue generated from ticket sales
  uint256 public startTime; // The start time of the ticket sale
  uint256 public endTime; // The end time of the ticket sale
  uint256 public discountPercentage; // The percentage discount applied to the base price of each ticket

  // Mapping to keep track of the number of tickets owned by each buyer
  mapping(address => uint256) public ticketBalances;

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
    symbol = _symbol;
    eventId = _eventId;
    tierId = _tierId;
    basePrice = _basePrice;
    initialPrice = _initialPrice;
    currentPrice = _initialPrice;
    totalTickets = _totalTickets;
    startTime = _startTime;
    endTime = _endTime;

    lastPriceUpdate = block.timestamp;

    priceUpdateInterval = 60; // 1 min
    decayPercentage = 100; // 1%
    salesTimeInterval = 30; // 30 secs

    // Create a new NFT contract for the event
    EventTicket nftContract = new EventTicket(string(abi.encodePacked(_eventName, " Ticket")), _symbol, _totalTickets, _baseURI);
    nftAddress = address(nftContract); // Set the address of the NFT contract
  }

  // Function to purchase a ticket
  function purchaseTicket() public payable {
    require(block.timestamp >= startTime, "sales not started yet");
    require(block.timestamp <= endTime, "sales ended");
    require(totalTickets > ticketsSold, "event sold out!");

    uint256 price = getCurrentPrice();
    require(msg.value >= price, "Current price is higher");

    EventTicket nftContract = EventTicket(nftAddress);

    // Mint new ticket NFT and transfer ownership to the buyer
    // for now, the purchased tickets go to the EOA that initiatied the purchase
    address buyer = tx.origin;
    nftContract.mint(buyer);

    // Update the ticket balance of the buyer
    ticketBalances[buyer]++;

    ticketsSold++;
    totalRevenue += msg.value;

    emit TicketPurchased(buyer, eventId, tierId, msg.value);
  }

  function getTickets() public view returns (TicketMeta memory) {
    // for now, only tx.origin can buy tickets
    // so return their balance
    uint256 count = ticketBalances[tx.origin];
    TicketMeta memory data = TicketMeta(eventName, tierId, symbol, count, nftAddress);
    return data;
  }

  // Function to get the current price of a ticket based on market conditions
  function getCurrentPrice() public returns (uint256) {
    require(block.timestamp >= startTime, "didn't started yet");
    require(block.timestamp <= endTime, "sales ended");
    uint256 ticketsLeft = totalTickets.sub(ticketsSold);
    require(ticketsLeft > 0, "sold out!");

    uint256 timeLeft = endTime.sub(block.timestamp).div(salesTimeInterval); // time left in the defined time interval (hours, days, mins, etc.)

    // Calculate the average number of tickets sold per time interval
    uint256 timeElapsed = block.timestamp.sub(startTime).div(salesTimeInterval);
    uint256 saleRate = 0;
    if (timeElapsed > 0) {
      saleRate = ticketsSold.div(timeElapsed);
    }

    // no sales rate, decrease current price
    if (saleRate == 0) {
      // if no sales, update price every 1 min (to be an adjustable param)
      if (block.timestamp.sub(lastPriceUpdate) > priceUpdateInterval) {
        // gradually decrease the price
        uint256 priceSpan = initialPrice.sub(basePrice);
        uint256 delta = priceSpan.div(decayPercentage);

        currentPrice = currentPrice.sub(delta);

        if (currentPrice < basePrice) {
          currentPrice = basePrice;
        }
        lastPriceUpdate = block.timestamp;

        emit PriceChanged(eventId, tierId, currentPrice);
      }

      return currentPrice;
    }

    // Calculate the target sale rate based on the remaining time and inventory
    // Sell remaining tickets in the remaining time
    if (timeLeft == 0) {
      timeLeft = 1;
    }
    uint256 targetSaleRate = ticketsLeft.div(timeLeft);
    if (targetSaleRate == 0) {
      targetSaleRate = 1;
    }

    // start at initial price
    // decrease if salesRate < targetRate
    // increase if salesRate > targetRate

    // Calculate the adjustment factor based on the difference
    // between the target and actual sale rates
    uint256 adjustmentFactor;
    if (saleRate >= targetSaleRate) {
      adjustmentFactor = (saleRate.sub(targetSaleRate)).mul(100).div(targetSaleRate);
      if (adjustmentFactor == 0) {
        uint256 priceSpan = initialPrice.sub(basePrice);
        adjustmentFactor = priceSpan.div(decayPercentage);
      }
      currentPrice = currentPrice.add(adjustmentFactor);
    } else {
      adjustmentFactor = (targetSaleRate.sub(saleRate)).mul(100).div(targetSaleRate);
      //Apply the adjustment factor to the base price
      currentPrice = currentPrice.sub(adjustmentFactor);
    }

    // price cannot be lower than basePrice
    if (currentPrice < basePrice) {
      currentPrice = basePrice;
    }
    lastPriceUpdate = block.timestamp;

    emit PriceChanged(eventId, tierId, currentPrice);

    return currentPrice;
  }

  // updateBasePrice function allows the contract owner to update the base ticket price for the event
  function updateBasePrice(uint256 newPrice) public onlyOwner {
    basePrice = newPrice;

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
    require(discountPercentage == 0, "cancel current discount to set a new one");
    require(percentage < 100, "should be less than 100%");
    require(percentage > 0, "should be positive number (0-99)");
    discountPercentage = percentage;
    basePrice = (basePrice * (100 - percentage)) / 100;
  }

  // cancelDiscount function allows the contract owner to cancel any previously set discount
  function cancelDiscount() public onlyOwner {
    require(discountPercentage > 0, "no discount to cancel");
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
    require(block.timestamp > endTime, "still active");
    (bool sent, ) = owner().call{ value: totalRevenue }("");
    require(sent, "Failed to withdraw");
  }
}
