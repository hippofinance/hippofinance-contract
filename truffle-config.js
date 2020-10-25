const path = require("path");
const accountIndex = 0;
require("dotenv").config({path: `${__dirname}/.env`});
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    rinkeby: {
      network_id: "4",
      provider: function () {
        return new HDWalletProvider(process.env.DEVMNEMONIC, "https://rinkeby.infura.io/v3/83301e4b4e234662b7769295c0f4a2e1", accountIndex)
      },
      gasPrice: 150000000000
    },
    goerli: {
      network_id: "5",
      provider: function () {
        return new HDWalletProvider(process.env.DEVMNEMONIC, "https://goerli.infura.io/v3/83301e4b4e234662b7769295c0f4a2e1", accountIndex)
      },
      gasLimit: 100000000,
      gasPrice: 50000000000
    },
    main: {
      network_id: "1",
      provider: function () {
        return new HDWalletProvider(process.env.PRODMNEMONIC, "https://mainnet.infura.io/v3/83301e4b4e234662b7769295c0f4a2e1", accountIndex)
      },
      gasPrice: 150000000000
    }
  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: true, // Default: false
          runs: 9999999     // Default: 200
        },
        evmVersion: "istanbul"  // Default: "byzantium"
      }
    }
  },
};
