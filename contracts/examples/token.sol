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
    function Token(
        string _name,
        string _symbol,
        uint8 _decimals
      ) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
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
