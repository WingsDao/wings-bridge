# Wings Bridge

This is Wings bridge, based on [custom crowdsale contract and integration](https://github.com/wingsdao/wings-integration) that allows only to provide collected amount and automatically move rewards to bridge smart contract.

It makes integration much simpler and easy to do.

## Requirements

- Nodejs v8
- Truffle
- Ganache-cli v6.0.3

## Flow

This Wings bridge contract works like communication contract, it allows to notify Wings about new contributions during crowdsale.

### Step by step guide ###

- Install this package as dependency for your smart contracts.
- Inherit your main `Crowdsale` contract from [`Connector`](https://github.com/WingsDao/wings-bridge/blob/master/contracts/Connector.sol) contract.
- Call method `notifySale` when sale/exchange of your tokens happen.
- Call method `closeBridge` and implement movement of rewards to bridge contract.
- Deploy your token/crowdsale etc contracts, deploy bridge contract, call method `changeBridge` on your crowdsale contract and pass there address of deployed bridge contract.
- Create project at Wings platform as custom contract and provide address of **bridge** contract.
- Call `transferManager` method on bridge contract and pass there DAO contract address generated by Wings.
- Call `start` for bridge before crowdsale start.

For more detailed explanations read next part of this tutorial.

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

    // transfer the state from mintable to transferrable
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

  // sells the project's token to buyers
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

```
npm i @wings_platform/wings-bridge --save
```

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
- `uint256 _tokenAmount` - is amount of tokens which were bought.

So we have method `sellTokens` in Crowdsale, where we usually sell tokens, in the end of this method we will add call to `notifySale`:

```sc
// call notifySale, _value - ETH amount, tokensSold - tokens amount
notifySale(_value, tokensSold);
```

To see how method looks now, see [example](https://github.com/WingsDao/wings-bridge/blob/master/contracts/examples/crowdsale.sol#L89).

And last thing we should in crowdsale source code, it's adding issue of rewards tokens, and closing bridge. Let's add
it to `releaseTokens` method.

```sc
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
```

So, with method `calculateRewards` we can get amount of rewards we have to pay.
**Important** call this method when crowdsale completed. It returns two values: reward in ETH and reward in tokens. If you don't have reward in ETH, the returned value ETH reward will be 0.

Another method is `closeBridge`, that report to bridge smart contract, that crowdsale completed.

See how it looks now in [examples](https://github.com/WingsDao/wings-bridge/blob/master/contracts/examples/crowdsale.sol#L53).

At this stage no more changes to source code are needed.

We should deploy our contracts right before we start forecasting on Wings platform.

So let's make a migration script, that will deploy token/crowdsale and bridge contract, and meanwhile set correct ownership logic in our contracts.


Let's require contracts first:

```js
const Crowdsale = artifacts.require('Crowdsale')
const Token = artifacts.require('Token')
const Bridge = artifacts.require('Bridge')
```


Deploying token and crowdsale:

```js
// Deploying token
await deployer.deploy(Token)
const token = await Token.deployed()

// Deploying Crowdsale
await deployer.deploy(Crowdsale, token.address)
const crowdsale = await Crowdsale.deployed()

// Move token owner to crowdsale
await token.transferOwnership(crowdsale.address)
```

Now let's deploy bridge and direct crowdsale to bridge:

```js
await deployer.deploy(Bridge, web3.toWei(10, 'ether'), web3.toWei(100, 'ether'), token.address, crowdsale.address)
const bridge = await Bridge.deployed()
```

If we look at Bridge constructor:

```sc
function Bridge(
    uint256 _minimalGoal,
    uint256 _hardCap,
    address _token,
    address _crowdsaleAddress
)
```

- `uint256 _minimalGoal` - minimal goal in wei, should be great then 10% of hard cap.
- `uint256 _hardCap` - hard cap in wei.
- `address _token` - token address.
- `address _crowdsaleAddress` - crowdsale address.

And then call to crowdsale to change bridge to deployed one:

```sc
await crowdsale.changeBridge(bridge.address)
```

Now we need to create project at Wings platform. We go to [Wings](https://wings.ai), fill project details, and at **Smart contract** tab we need to select __Custom Contract__ and put **Bridge Contract Address** to __Contract address__ field.

Like on image:

![contract address](https://i.imgur.com/myATGnp.png)

Once you've created your project and forecasting started, you have time to move bridge manager under control of DAO contract address.

To do it, just take URL of your project, like:

https://wings.ai/project/0x28e7f296570498f1182cf148034e818df723798a

As you see - `0x28e7f296570498f1182cf148034e818df723798a`, it's your DAO contract address. You can check it via parity or some other ethereum clients/tools, your account that you used to project at [wings.ai](https://wings.ai) is owner of this smart contract.

So we take this address, and move manager of bridge to this address, we use `transferManager` method for it.

**IMPORTANT**: all this steps can go during you forecasting period.

Like:

```js
await bridge.transferManager('0x28e7f296570498f1182cf148034e818df723798a')
```

Ok, when it's done, let's make the last small step, you need to start your bridge.
To accomplish this, you need to call few methods on DAO contract, indeed `createCustomCrowdsale` method and  `start` method at your crowdsale controller contract, that will be generated by `createCustomCrowdsale` call.

Here is [ABI](https://github.com/WingsDao/wings-bridge/tree/master/ABI) for contracts and we recommend to use [truffle contract](https://github.com/trufflesuite/truffle-contract) library to make calls.

**IMPORTANT**: use same account that you used to create project at [wings.ai](https://wings.ai)

Like:

```sc
const dao = await DAO.at('0x28e7f296570498f1182cf148034e818df723798a') // change with your DAO address
await dao.createCustomCrowdsale()
```

And:

```sc
const ccAddress = await dao.crowdsaleController.call()
const crowdsaleController = await CrowdsaleController.at(ccAddress)
await crowdsaleController.start(0, 0, '0x0')
```

**IMPORTANT**: values like 0, 0, '0x0' for start work fine only if you are using bridge, if you done full integration, do it in another way.

That's it. You can start your crowdsale!

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
