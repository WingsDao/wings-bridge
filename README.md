# Wings Bridge

This is Wings bridge, based on [custom crowdsale contract and integration](https://github.com/wingsdao/wings-integration) that allowing only to provide collected amount and automatically move rewards on bridge smart contract. 

It makes integration much simple and easy to do. 

## Requirements

- Nodejs v8
- Truffle
- Testrpc

## Flow

This Wings bridge contract works like communication contract, allows to message to Wings amount that ICO collecting during crowdsale. 

What you need to do step by step:

- Install this package as dependency for your smart contracts.
- Inherit your main Crowdsale contract from [Connector](https://github.com/WingsDao/wings-bridge/blob/master/contracts/Connector.sol) contract.
- Call method `notifySale` when sale/exchange of your tokens happen.
- Call method `closeBridge` and impelement movement of rewards to bridge contract.
- Deploy your token/crowdsale etc contracts, deploy bridge contract, call method `changeBridge` on your crowdsale contract and pass there address of deployed bridge contract.
- Create project on Wings, as 3rd party crowdsale contract provide address of **bridge** contract.
- Call `transferManager` method on bridge contract and pass there DAO contract address generated by Wings. 

For more details read next part of this tutorial.

## Integration 

On example of standard crowdsale contract we will do bridge integration. **Important**: this is just tutorial and shows one of the many ways to integrate bridge contract, everything based on your own crowdsale contract. Don't use this example on mainnet. 

Let's take a standard token and crowdsale contract. Token contract is mintable, so we will use token to issue new tokens, manage issue will be done by crowdsale contract (that will be owner of token contract).
  
Token contract:
```sc
pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

// Minimal crowdsale token for custom contracts
contract Token is Ownable, StandardToken {
    // ERC20 requirements
    string public name;
    string public symbol;
    uint8 public decimals;

    // how many tokens was created (i.e. minted)
    uint256 public totalSupply;

    // here are 2 states: mintable (initial) and transferrable
    bool public releasedForTransfer;

    // Ctor. Hardcodes names in this example
    function Token() public {
        name = "CustomTokenExample";
        symbol = "CTE";
        decimals = 18;
    }

// override these 2 functions to prevent from transferring tokens before it was released

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(releasedForTransfer);
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(releasedForTransfer);
        return super.transferFrom(_from, _to, _value);
    }

    // transfer the state from intable to transferrable
    function release() public
        onlyOwner() // only owner can do it
    {
        releasedForTransfer = true;
    }

    // creates new amount of the token from a thin air
    function issue(address _recepient, uint256 _amount) public
        onlyOwner() // only owner can do it
    {
        // the owner can mint until released
        require (!releasedForTransfer);

        // total token supply increases here.
        // Note that the recepient is not able to transfer anything until release() is called
        balances[_recepient] += _amount;
        totalSupply += _amount;
    }
}

```

Crowdsale contract:

```sc
pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Token.sol";

// Example of crowdsale. NOT FOR REAL USAGE
contract Crowdsale is Ownable {
  modifier onlyActive() {
    require(active);
    _;
  }

  modifier finished() {
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
  function finish() onlyOwner() onlyActive() {
    active = false;
  }

  // if there is ETH rewards and all ETH already withdrawn
  function deposit() public payable finished() {
  }

  // transfers crowdsale token from mintable to transferrable state
  function releaseTokens()
    public
    onlyOwner()
    finished()
  {
    crowdsaleToken.release();
  }


  // default function allows for ETH transfers to the contract
  function () payable public {
    require(msg.value > 0);

    // and it sells the token
    sellTokens(msg.sender, msg.value);
  }

  // sels the project's token to buyers
  function sellTokens(address _recepient, uint256 _value)
    internal
    onlyActive()
  {
    require(totalCollected < hardCap);
    uint256 newTotalCollected = totalCollected + _value;

    if (hardCap < newTotalCollected) {
      // don't sell anything above the hard cap

      uint256 refund = newTotalCollected - hardCap;
      uint256 diff = _value - refund;

      // send the ETH part which exceeds the hard cap back to the buyer
      _recepient.transfer(refund);
      _value = diff;
    }

    // token amount as per price (fixed in this example)
    uint256 tokensSold = _value * tokensPerEthPrice;

    // create new tokens for this buyer
    crowdsaleToken.issue(_recepient, tokensSold);

    // update total ETH collected
    totalCollected += _value;
  }

  // project's owner withdraws ETH funds to the funding address upon successful crowdsale
  function withdraw(
    uint256 _amount // can be done partially
  )
    public
  {
    require(_amount <= this.balance);
    owner.transfer(_amount);
  }
}
```

Now let's add support of Connector contract to crowdsale contract.

```sc
import "@wings_platform/wings-bridge/contracts/Connector.sol";
```

And inherit Crowdsale from Connector.

```sc
contract Crowdsale is Connector {
```

Connector is already inherits from `Ownable` so we don't need to inherit again.

Now our goal to call `notifySale` on each call, method looks so in Connector contract:

```sc 
function notifySale(uint256 _ethAmount, uint256 _tokenAmount) internal bridgeInitialized {
    bridge.notifySale(_ethAmount, _tokenAmount);
}
```

- `uint256 _ethAmount` - is amount of ETH that was sent to buy tokens.
- `uint256 _tokenAmount` - is amount of tokens that bought.

So we have method `sellTokens` in Crowdsale, where we usually sell tokens, in the end of this method we will add call of `notifySale`:

```sc
    // call notifySale, _value - ETH amount, tokensSold - tokens amount
    notifySale(_value, tokensSold);
```

## Developing

We recommend to make pull requests to current repository. Each pull request should be covered with tests. 

Fetch current repository, install dependencies:

    npm install

We strongly recommend to develop using [testrpc](https://github.com/trufflesuite/ganache-cli) to save time and cost. 

## Tests

To run tests fetch current repository, install dependencies and run:

    truffle test

## Authors

Wings Stiftung

## License

See in [license file](https://github.com/WingsDao/wings-bridge/blob/master/LICENSE).
