pragma solidity ^0.4.18;

import "./Bridge.sol";

contract Connector is Ownable {
  modifier bridgeInitialized() {
    require(address(bridge) != address(0x0));
    _;
  }

  Bridge public bridge;

  function changeBridge(address _bridge) public onlyOwner {
    require(_bridge != address(0x0));
    bridge = Bridge(_bridge);
  }

  function notifySale(uint256 _ethAmount, uint256 _tokenAmount) internal bridgeInitialized {
    bridge.notifySale(_ethAmount, _tokenAmount);
  }

  function closeBridge() internal bridgeInitialized {
    bridge.finish();
  }
}
