// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./ExampleExternalContract.sol";

contract Staker {
  ExampleExternalContract public exampleExternalContract;

  mapping (address => uint256) public balances;

  uint256 public constant threshold = 1 ether;

  /// Staking deadline
  uint256 public deadline = block.timestamp + 72 hours;

  /// Boolean set if threshold is not reached by the deadline
  bool public openForWithdraw;

  event Stake(address indexed sender, uint256 indexed value);

  // MODIFIERS
  /// Modifier that checks whether the required deadline has passed
  modifier deadlinePassed(bool requireDeadlinePassed) {
    uint256 timeRemaining = timeLeft();
    if (requireDeadlinePassed) {
      require(timeRemaining <= 0, "Deadline has not been passed yet");
    } else {
      require(timeRemaining > 0, "Deadline is already passed");
    }
    _;
  }

  /// Modifier that checks whether the external contract is completed
  modifier stakingNotCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "Staking period has completed");
    _;
  }

  constructor(address exampleExternalContractAddress)  {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable deadlinePassed(false) stakingNotCompleted {
    // update the sender's balance
    balances[msg.sender] += msg.value;

    // emit Stake event to notify the UI
    emit Stake(msg.sender, msg.value);
  }


  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public stakingNotCompleted {
    uint256 contractBalance = address(this).balance;
    if (contractBalance >= threshold) {
      // if the `threshold` is met, send the balance to the externalContract
      exampleExternalContract.complete{value: contractBalance}();
    } else {
      // if the `threshold` was not met, allow everyone to call a `withdraw()` function
      openForWithdraw = true;
    }
  }



  // Add a `withdraw(address payable)` function lets users withdraw their balance
  function withdraw() public deadlinePassed(true) stakingNotCompleted {
    
      uint256 userBalance = balances[msg.sender];

      // reset the sender's balance
      balances[msg.sender] = 0;

      // transfer sender's balance to the `_to` address
      (bool sent, ) = msg.sender.call{value: userBalance}("");
      
      // check the amount staked did not reach the threshold by the deadline
      require(openForWithdraw && userBalance > 0 && sent, "Withdrawal fail");
  }

  /// Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256) {
      if (block.timestamp >= deadline) {
          return 0;
      } else {
          return deadline - block.timestamp;
      }
  }


  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
      stake();
  }
}