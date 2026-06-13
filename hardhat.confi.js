// hardhat.config.js
require("dotenv").config();

const REQUIRED_ENV_VARS = {
  DEPLOYER_PRIVATE_KEY: process.env.DEPLOYER_PRIVATE_KEY,
  SEPOLIA_RPC_URL: process.env.SEPOLIA_RPC_URL,
};

const missingVars = Object.entries(REQUIRED_ENV_VARS)
  .filter(([_, value]) => !value)
  .map(([key]) => key);

if (missingVars.length > 0) {
  throw new Error(
    `Missing required environment variables: ${missingVars.join(", ")}\n` +
    `Check your .env file or set them manually.`
  );
}

module.exports = {
  // Your config here
};