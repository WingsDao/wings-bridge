const Bridge = artifacts.require('Bridge')
const Crowdsale = artifacts.require('Crowdsale')
const Token = artifacts.require('Token')

module.exports = async (deployer) => {
  await deployer.deploy(Token)

  const token = await Token.deployed()

  await deployer.deploy(Crowdsale, token.address)

  const crowdsale = await Crowdsale.deployed()

  await token.transferOwnership(crowdsale.address)

  await deployer.deploy(Bridge, token.address, crowdsale.address)

  const bridge = await Bridge.deployed()

  await crowdsale.changeBridge(bridge.address)

  console.log('\n\n\n============================================')
  console.log(`Token: ${token.address}`)
  console.log(`Crowdsale: ${crowdsale.address}`)
  console.log(`Bridge: ${bridge.address}`)
  console.log('\n\n\n')
}
