pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  uint256 deadline = block.timestamp + 5 minutes;
  uint256 threshold = 1 ether; 

  bool allowWithdraw = false;
  
  ExampleExternalContract public exampleExternalContract;

  event Stake(address, uint256);

  mapping(address => uint) public balances;

  modifier deadlineReached( bool requiredReached ) {
    uint256 timeRemaining = timeLeft();
    if( requiredReached ) {
      require(timeRemaining == 0, "Deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Deadline is already reached");
    }
    _;
  }

  modifier stakeNotCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "staking process already completed");
    _;
  }

  constructor(address exampleExternalContractAddress) public {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable deadlineReached(false) stakeNotCompleted {
    balances[msg.sender] = msg.value;

    emit Stake(msg.sender, msg.value); 
  }

  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
   // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function execute() public deadlineReached(false) stakeNotCompleted {
    uint256 contractBalance = address(this).balance;

    require(contractBalance >= threshold, "Threshold not reached");

      // Execute the external contract, transfer all the balance to the contract
    // (bool sent, bytes memory data) = exampleExternalContract.complete{value: contractBalance}();
    (bool sent,) = address(exampleExternalContract).call{value: contractBalance}(abi.encodeWithSignature("complete()"));
    require(sent, "exampleExternalContract.complete failed");
  }

   // Add a `withdraw(address payable)` function lets users withdraw their balance
  /**
  * @notice Allow users to withdraw their balance from the contract only if deadline is reached but the stake is not completed
  */
  function withdraw() public deadlineReached(false) stakeNotCompleted {
    uint256 userBalance = balances[msg.sender];

    // check if the user has balance to withdraw
    require(userBalance > 0, "You don't have a balance to withdraw");

    // reset the blance of the user
    balances[msg.sender] = 0;

    // transfer balance back to the user
    (bool sent, bytes memory data) = msg.sender.call{value: userBalance}("");
    require(sent, "Failed to send user balance back to the user");
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  /**
  * @notice The number of seconds remaining until the deadline is reached
  */
  function timeLeft() public view returns (uint256 timeleft) {
    if (block.timestamp >= deadline) {
      return 0;
    } else {
      return deadline - block.timestamp;
    }

  }

  // Add the `receive()` special function that receives eth and calls stake()
  function receive() public payable {
    console.log(msg.value);
    stake();
  }
}
