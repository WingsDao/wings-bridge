const should = require('chai').should()
const BigNumber = require('bignumber.js')

const Bridge = artifacts.require('Bridge')
const Crowdsale = artifacts.require('Crowdsale')
const Token = artifacts.require('Token')
const ControllerStub = artifacts.require('ControllerStub')

let sendETH = (txObject) => {
  return new Promise((resolve, reject) => {
    web3.eth.sendTransaction(txObject, (err, txId) => {
      err? reject(err) : resolve(txId)
    })
  })
}

contract('Bridge', (accounts) => {
  let creator = accounts.splice(0, 1).pop()
  let participant = accounts.splice(0, 1).pop()

  const rewards = {
    tokens: 100000,
    eth: 100000
  }

  let toSend = web3.toWei(1, 'ether')
  let totalCollected, totalSold

  let token, crowdsale, controller, bridge

  before(async () => {
    // deploy token
    token = await Token.new({
      from: creator
    })

    // deploy crowdsale
    crowdsale = await Crowdsale.new(token.address, {
      from: creator
    })

    // move token under crowdsale control
    await token.transferOwnership(crowdsale.address, {
      from: creator
    })

    // deploy bridge
    bridge = await Bridge.new(
      token.address,
      crowdsale.address,
      {
        from: creator
      }
    )

    // set bridge for crowdsale
    await crowdsale.changeBridge(bridge.address, {
      from: creator
    })

    // controller stub just for manager
    controller = await ControllerStub.new(
      rewards.eth,
      rewards.tokens,
      {
        from: creator
      }
    )

    // start crowdsale (in wings will be done in controller)
    await bridge.start(0, 0, '0x0', {
      from: creator
    })
  })

  it('should participate in crowdsale', async () => {
    await sendETH({
      from: participant,
      to: crowdsale.address,
      value: toSend,
      gas: 500000
    })

    const price = await crowdsale.tokensPerEthPrice.call()
    totalSold = price.mul(toSend)
  })

  it('should generate tokens for participant', async () => {
    const balance = await token.balanceOf.call(participant)
    totalSold.toString(10).should.be.equal(balance.toString(10))
  })

  it('should update total sold value in bridge', async () => {
    const bgSold = await bridge.totalSold.call()
    bgSold.toString(10).should.be.equal(totalSold.toString(10))
  })

  it('should update total collected value in bridge', async () => {
    const bgCollected = await bridge.totalCollected.call()
    bgCollected.toString(10).should.be.equal(toSend.toString(10))
  })

  it('should finish crowdsale', async () => {
    await crowdsale.finish({
      from: creator
    })
  })

  it('should transfer bridge management to controller', async () => {
    await bridge.transferManager(controller.address, {
      from: creator
    })
  })

  it('should release tokens', async () => {
    await crowdsale.releaseTokens({
      from: creator
    })
  })

  it('should withdraw ETH', async () => {
    const balance = web3.eth.getBalance(crowdsale.address)
    await crowdsale.withdraw(balance, {
      from: creator
    })
  })

  it('should finish bridge', async () => {
    const completed = await bridge.completed.call()
    completed.should.be.equal(true)
  })

  it('should have tokens reward at bridge contract', async () => {
    const tokenReward = new BigNumber(totalSold).mul(rewards.tokens).div(1000000)
    const balance = await token.balanceOf.call(bridge.address)

    balance.toString(10).should.be.equal(tokenReward.toString(10))
  })

  it('should have eth reward at bridge contract', async () => {
    const ethReward = new BigNumber(toSend).mul(rewards.eth).div(1000000)
    const balance = web3.eth.getBalance(bridge.address)

    balance.toString(10).should.be.equal(ethReward.toString(10))
  })
})
