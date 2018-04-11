const Bridge = artifacts.require('Bridge')
const Crowdsale = artifacts.require('Crowdsale')
const Token = artifacts.require('Token')

module.exports = async (deployer) => {
  /*await deployer.deploy(Token, "Arcona Distribution Contract", "ARN", 18, {
    from: '0x00467bb29aE380bf731C30f44bfA074306b0a257',
    gas: 3000000,
    gasPrice: web3.toWei(10, 'gwei')
  })

  const token = await Token.deployed()*/

  await deployer.deploy(Bridge, web3.toWei(5555.5, 'ether'), web3.toWei(55555, 'ether'), '0x26F88E05b5E0adbB8F3f0A05eaa4a48a45F6768B', {
    from: '0x00467bb29aE380bf731C30f44bfA074306b0a257',
    gas: 3000000,
    gasPrice: web3.toWei(10, 'gwei')
  })

  const bridge = await Bridge.deployed()

  console.log('\n\n\n============================================')
  console.log(`Token: ${token.address}`)
  console.log(`Bridge: ${bridge.address}`)
  console.log('\n\n\n')
}
