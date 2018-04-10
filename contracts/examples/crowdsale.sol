pragma solidity ^0.4.18;

import "../Connector.sol";
import "./Token.sol";

// Example of crowdsale. NOT FOR REAL USAGE
contract Crowdsale is Connector {
  modifier whenActive() {
    require(active);
    _;
  }

  modifier whenFinished() {
    require(!active);
    _;
  }

  // tokens per ETH fixed price
  uint256 public tokensPerEthPrice = 500;

  // Crowdsale token
  Token public crowdsaleToken;

  // hard cap
  uint256 public hardCap = 1000 ether;

  // total collected
  uint256 public totalCollected = 0;

  bool public active;

  function Crowdsale(
    address _token
  )
    public
  {
    owner = msg.sender;
    crowdsaleToken = Token(_token);

    active = true;
  }

  // just for tests
  function finish() onlyOwner() whenActive() {
    active = false;
  }

  // if there is ETH rewards and all ETH already withdrawn
  function deposit() public payable whenFinished() {
  }

  // transfers crowdsale token from mintable to transferrable state
  function releaseTokens()
    public
    onlyOwner()
    whenFinished()
  {
    // see token example
    // send rewards
    uint256 ethReward = 0;
    uint256 tokenReward = 0;

    (ethReward, tokenReward) = bridge.calculateRewards();

    if (ethReward > 0) {
      bridge.transfer(ethReward);
    }

    if (tokenReward > 0) {
      crowdsaleToken.issue(bridge, tokenReward);
    }

    // close bridge
    closeBridge();

    crowdsaleToken.release();
  }


  // default function allows for ETH transfers to the contract
  function () payable public {
    require(msg.value > 0);

    // and it sells the token
    sellTokens(msg.sender, msg.value);
  }

  // sels the project's token to buyers
  function sellTokens(address _recipient, uint256 _value)
    internal
    whenActive()
  {
    require(totalCollected < hardCap);
    uint256 newTotalCollected = totalCollected + _value;

    if (hardCap < newTotalCollected) {
      // don't sell anything above the hard cap

      uint256 refund = newTotalCollected - hardCap;
      uint256 diff = _value - refund;

      // send the ETH part which exceeds the hard cap back to the buyer
      _recipient.transfer(refund);
      _value = diff;
    }

    // token amount as per price (fixed in this example)
    uint256 tokensSold = _value * tokensPerEthPrice;

    // create new tokens for this buyer
    crowdsaleToken.issue(_recipient, tokensSold);

    // update total ETH collected
    totalCollected += _value;

    notifySale(_value, tokensSold);
  }

  // project's owner withdraws ETH funds to the funding address upon successful crowdsale
  function withdraw(
    uint256 _amount // can be done partially
  )
    public
    onlyOwner()
  {
    require(_amount <= this.balance);
    owner.transfer(_amount);
  }
}
