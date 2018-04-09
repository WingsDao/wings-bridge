const Bridge = artifacts.require('Bridge')
const Crowdsale = artifacts.require('Crowdsale')
const Token = artifacts.require('Token')

module.exports = async (deployer) => {
  await deployer.deploy(Token, "Arcona Distribution Contract", "ARN", 18)

  const token = await Token.deployed()

  await deployer.deploy(Bridge, web3.toWei(5555.5, 'ether'), web3.toWei(55555, 'ether'), token.address)

  const bridge = await Bridge.deployed()

  console.log('\n\n\n============================================')
  console.log(`Token: ${token.address}`)
  console.log(`Bridge: ${bridge.address}`)
  console.log('\n\n\n')
}
