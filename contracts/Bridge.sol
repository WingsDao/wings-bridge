pragma solidity ^0.4.18;

import 'wings-integration/contracts/BasicCrowdsale.sol';
import 'zeppelin-solidity/contracts/token/ERC20/BasicToken.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

import './IWingsController.sol';

/*
  Implements custom crowdsale as bridge
*/
contract Bridge is BasicCrowdsale {
  using SafeMath for uint256;

  // Crowdsale token
  BasicToken token;

  // is crowdsale completed
  bool public completed;

  // Ctor. In this example, minimalGoal, hardCap, and price are not changeable.
  // In more complex cases, those parameters may be changed until start() is called.
  function Bridge(
    uint256 _minimalGoal,
    uint256 _hardCap,
    address _token
  )
    public
    // simplest case where manager==owner. See onlyOwner() and onlyManager() modifiers
    // before functions to figure out the cases in which those addresses should differ
    BasicCrowdsale(msg.sender, msg.sender)
  {
    // just setup them once...
    minimalGoal = _minimalGoal;
    hardCap = _hardCap;
    token = BasicToken(_token);
  }

// Here goes ICrowdsaleProcessor implementation

  // returns address of crowdsale token. The token must be ERC20-compliant
  function getToken()
    public
    returns(address)
  {
    return address(token);
  }

  // called by CrowdsaleController to transfer reward part of
  // tokens sold by successful crowdsale to Forecasting contract.
  // This call is made upon closing successful crowdfunding process.
  function mintTokenRewards(
    address _contract,  // Forecasting contract
    uint256 _amount     // agreed part of totalSold which is intended for rewards
  )
    public
    onlyManager() // manager is CrowdsaleController instance
  {
    // crowdsale token is mintable in this example, tokens are created here
    token.transfer(_contract, _amount);
  }

  // transfers crowdsale token from mintable to transferrable state
  function releaseTokens()
    public
    onlyManager()             // manager is CrowdsaleController instance
    hasntStopped()            // crowdsale wasn't cancelled
    whenCrowdsaleSuccessful() // crowdsale was successful
  {
    // empty for bridge
  }

// Here go crowdsale process itself and token manipulations

  // default function allows for ETH transfers to the contract
  function () payable public {
  }

  function notifySale(uint256 _ethAmount, uint256 _tokensAmount) public
    hasBeenStarted()     // crowdsale started
    hasntStopped()       // wasn't cancelled by owner
    whenCrowdsaleAlive() // in active state
    onlyOwner() // can do only crowdsale
  {
    totalCollected = totalCollected.add(_ethAmount);
    totalSold += totalSold.add(_tokensAmount);
  }

  // finish collecting data
  function finish() public
    hasntStopped()
    hasBeenStarted()
    whenCrowdsaleAlive()
    onlyOwner()
  {
    completed = true;
  }

  // project's owner withdraws ETH funds to the funding address upon successful crowdsale
  function withdraw(
    uint256 _amount // can be done partially
  )
    public
    onlyOwner() // project's owner
    hasntStopped()  // crowdsale wasn't cancelled
    whenCrowdsaleSuccessful() // crowdsale completed successfully
  {
    // nothing to withdraw
  }

  // backers refund their ETH if the crowdsale was cancelled or has failed
  function refund()
    public
  {
    // nothing to refund
  }

  // called by CrowdsaleController to setup start and end time of crowdfunding process
  // as well as funding address (where to transfer ETH upon successful crowdsale)
  function start(
    uint256 _startTimestamp,
    uint256 _endTimestamp,
    address _fundingAddress
  )
    public
    onlyManager()   // manager is CrowdsaleController instance
    hasntStarted()  // not yet started
    hasntStopped()  // crowdsale wasn't cancelled
  {
    // just start crowdsale
    started = true;

    CROWDSALE_START(_startTimestamp, _endTimestamp, _fundingAddress);
  }

  // must return true if crowdsale is over, but it failed
  function isFailed()
    public
    constant
    returns(bool)
  {
    return (
      false
    );
  }

  // must return true if crowdsale is active (i.e. the token can be bought)
  function isActive()
    public
    constant
    returns(bool)
  {
    return (
      // we remove timelines
      started && !completed
    );
  }

  // must return true if crowdsale completed successfully
  function isSuccessful()
    public
    constant
    returns(bool)
  {
    return (
      completed
    );
  }

  function calculateRewards() public view returns(uint256,uint256) {
    uint256 tokenRewardPart = IWingsController(manager).tokenRewardPart();
    uint256 ethRewardPart = IWingsController(manager).ethRewardPart();

    uint256 tokenReward = totalSold.mul(tokenRewardPart) / 1000000;
    bool hasEthReward = (ethRewardPart != 0);

    uint256 ethReward = 0;
    if (hasEthReward) {
        ethReward = totalCollected.mul(ethRewardPart) / 1000000;
    }

    return (ethReward, tokenReward);
  }

  function changeToken(address _newToken) onlyOwner {
    token = BasicToken(_newToken);
  }
}
