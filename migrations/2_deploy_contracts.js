const Conference = artifacts.require('./Conference.sol');
const Web3 = require('web3');

const options = Object.values({
  name: 'Test',
  deposit: Web3.utils.toWei('0.01', 'ether'),
  limitOfParticipants: 10,
  coolingPeriod: 60 * 60 * 24 * 7,
  encryption: '',
});

module.exports = async function(deployer) {
  await deployer;
  return deployer.deploy.apply(deployer, [Conference, ...options]);
};
