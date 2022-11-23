require('dotenv').config();

require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts',
  },
  defaultNetwork: 'localhost',
  networks: {
    hardhat: {
      forking: {
        enabled: true,
        url: 'https://polygon-testnet.public.blastapi.io',
        // blockNumber: 24243078,
        accounts: [
          process.env.PRIVATE_KEY_OWNER,
          process.env.PRIVATE_KEY_USER_1,
          process.env.PRIVATE_KEY_USER_2,
          process.env.PRIVATE_KEY_FEE,
        ],
      },
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      accounts: [
        process.env.PRIVATE_KEY_OWNER,
        process.env.PRIVATE_KEY_USER_1,
        process.env.PRIVATE_KEY_USER_2,
        process.env.PRIVATE_KEY_FEE,
      ],
    },
    mumbai: {
      url: 'https://polygon-testnet.public.blastapi.io',
      accounts: [
        process.env.PRIVATE_KEY_OWNER,
        process.env.PRIVATE_KEY_USER_1,
        process.env.PRIVATE_KEY_USER_2,
        process.env.PRIVATE_KEY_FEE,
      ],
    },
  },
};
