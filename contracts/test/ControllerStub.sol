pragma solidity ^0.4.18;

import "../IWingsController.sol";

// Minimal crowdsale token for custom contracts
contract ControllerStub is IWingsController {
  function ControllerStub(uint256 _ethRewardPart, uint256 _tokenRewardPart) {
    ethRewardPart = _ethRewardPart;
    tokenRewardPart = _tokenRewardPart;
  }

  function() public payable {
  }
}
