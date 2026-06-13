{
  "name": "dao-governance-system",
  "version": "1.0.0",
  "description": "Complete DAO Governance System with OpenZeppelin",
  "main": "index.js",
  "scripts": {
    "test": "npx hardhat test",
    "test:coverage": "npx hardhat coverage",
    "compile": "npx hardhat compile",
    "deploy:sepolia": "npx hardhat run scripts/deploy.js --network sepolia",
    "deploy:localhost": "npx hardhat run scripts/deploy.js --network localhost",
    "node": "npx hardhat node",
    "frontend": "cd frontend && python3 -m http.server 3000",
    "clean": "npx hardhat clean"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomiclabs/hardhat-etherscan": "^3.1.7",
    "chai": "^4.3.7",
    "dotenv": "^16.3.1",
    "hardhat": "^2.19.0",
    "hardhat-gas-reporter": "^1.0.9"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "ethers": "^6.8.0",
    "web3": "^4.2.0"
  }
}