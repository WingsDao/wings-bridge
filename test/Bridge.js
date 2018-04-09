const chai = require('chai')
const BigNumber = require('bignumber.js')
chai.should()

const Bridge = artifacts.require('Bridge');
const Token = artifacts.require('Token');
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

  let toSend = new BigNumber(web3.toWei(1, 'ether'))
  let totalCollected, totalSold

  let token, crowdsale, controller, bridge

  before(async function () {
    // deploy token
    token = await Token.new("Arcona Distribution Contract", "ARN", 18, {
      from: creator
    })

    // deploy bridge
    bridge = await Bridge.new(
      web3.toWei(5555, 'ether'),
      web3.toWei(55555, 'ether'),
      token.address,
      {
        from: creator
      }
    )

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

  it('should allow to change token', async () => {
    await bridge.changeToken(token.address, {
      from: creator
    })
  })

  it('should participate in crowdsale', async () => {
    totalSold = toSend.mul(1000)
    await token.issue(participant, totalSold, {
      from: creator
    })
  })

  it('should generate tokens for participant', async () => {
    const balance = await token.balanceOf.call(participant)
    totalSold.toString(10).should.be.equal(balance.toString(10))
  })

  it('should notify sale', async () => {
    await bridge.notifySale(toSend, totalSold, {
      from: creator
    })
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
    await bridge.finish({
      from: creator
    })
  })

  it('should move bridge manager to controller', async () => {
    await bridge.transferManager(controller.address, {
      from: creator
    })
  })

  it('should issue rewards tokens and eth', async () => {
    const [ethReward, tokenReward] = await bridge.calculateRewards.call()

    await token.issue(bridge.address, tokenReward)
    await sendETH({
      from: creator,
      to: bridge.address,
      value: ethReward,
      gas: 500000
    })
  })

  it('should finish bridge', async () => {
    const completed = await bridge.completed.call()
    completed.should.be.equal(true);
  })

  it('should has tokens reward on contract', async () => {
    const tokenReward = new BigNumber(totalSold).mul(rewards.tokens).div(1000000);
    const balance = await token.balanceOf.call(bridge.address)

    balance.toString(10).should.be.equal(tokenReward.toString(10))
  })

  it('should has eth reward on contract', async () => {
    const ethReward = new BigNumber(toSend).mul(rewards.eth).div(1000000)
    const balance = web3.eth.getBalance(bridge.address)

    balance.toString(10).should.be.equal(ethReward.toString(10))
  })
})
