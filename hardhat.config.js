// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// Destructure with fallback values
const { 
  SEPOLIA_RPC_URL, 
  MAINNET_RPC_URL,
  DEPLOYER_PRIVATE_KEY,
  ETHERSCAN_API_KEY 
} = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      // Default local network
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: SEPOLIA_RPC_URL || "",
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    mainnet: {
      url: MAINNET_RPC_URL || "",
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      chainId: 1,
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  }
};