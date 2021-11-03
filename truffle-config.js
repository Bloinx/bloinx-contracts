const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config()
const path = require("path");
const Web3 = require('web3');
const ContractKit = require('@celo/contractkit');
const web3 = new Web3('https://alfajores-forno.celo-testnet.org');
const kit = ContractKit.newKitFromWeb3(web3);

async function awaitCeloWrapper() {
  kit.connection.addAccount(process.env.CELO_PRIVATE_KEY)
}
awaitCeloWrapper();

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  contracts_build_directory: path.join(__dirname, "client/src/abis"),
  networks: {
    develop: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    ropsten: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, `https://ropsten.infura.io/v3/${process.env.PROJECT_ID}`),
      network_id: 3
    },
    avalanche_fuji: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, `https://api.avax-test.network/ext/bc/C/rpc`),
      port: 443,
      chain_id:43113,
      network_id: "*",
      gas: 3000000,
      gasPrice: 225000000000
    },
    alfajores: {
      provider: kit.connection.web3.currentProvider,
      network_id: 44787
    }
  },
  mocha: {

  },
  compilers: {
    solc: {
      version: "0.7.4",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    },
  },
};