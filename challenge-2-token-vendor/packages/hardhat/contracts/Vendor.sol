pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
  /// Reference to our ERC20 token contract
  YourToken public yourToken;

  /// Our token price
  uint256 public constant tokensPerEth = 100;

  // Events
  event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
  event SellTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);

  constructor(address tokenAddress) {
    yourToken = YourToken(tokenAddress);
  }

  /// Allow users to buy tokens
  function buyTokens() public payable {
    // Validate the user sent eth
    uint256 amountOfEth = msg.value;
    require(amountOfEth > 0, "Send some ETH to buy tokens");

    // Validate the vendor has enough tokens
    uint256 amountOfTokens = amountOfEth * tokensPerEth;
    uint256 vendorBalance = yourToken.balanceOf(address(this));
    require(vendorBalance >= amountOfTokens, "Vendor does not have enough tokens");

    // Send the tokens
    address buyer = msg.sender;
    (bool sent) = yourToken.transfer(buyer, amountOfTokens);
    require(sent, "Failed to transfer token");

    // Emit buy event
    emit BuyTokens(buyer, amountOfEth, amountOfTokens);
  }

  /// Allow the owner to withdraw ETH
  function withdraw() public onlyOwner {
    // Validate the vendor has ETH to withdraw
    uint256 vendorBalance = address(this).balance;
    require(vendorBalance > 0, "Vendor does not have any ETH to withdraw");

    // Send ETH
    address owner = msg.sender;
    (bool sent, ) = owner.call{value: vendorBalance}("");
    require(sent, "Failed to withdraw");
  }

  /// Allow users to sell tokens back to the vendor
  function sellTokens(uint256 amount) public {
    // Validate token amount
    require(amount > 0, "Must sell a token amount greater than 0");

    // Validate the user has the tokens to sell
    address user = msg.sender;
    uint256 userBalance = yourToken.balanceOf(user);
    require(userBalance >= amount, "User does not have enough tokens");

    // Validate the vendor has enough ETH
    uint256 amountOfEth = amount / tokensPerEth;
    // uint256 vendorEthBalance = address(this).balance;
    // require(vendorEthBalance > amountOfEth, "Vendor does not have enough ETH");

    // Transfer tokens
    (bool sent) = yourToken.transferFrom(user, address(this), amount);
    require(sent, "Failed to transfer tokens");

    // Transfer ETH
    (bool ethSent, ) = user.call{value: amountOfEth }("");
    require(ethSent, "Failed to send back eth");

    // Emit sell event
    emit SellTokens(user, amountOfEth, amount);
  }
}