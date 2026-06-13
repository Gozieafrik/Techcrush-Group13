{
  "name": "dao-event-ticket-system",
  "version": "1.0.0",
  "description": "Decentralized DAO Governance with NFT Event Tickets",
  "main": "truffle-config.js",
  "scripts": {
    "test": "truffle test",
    "compile": "truffle compile",
    "migrate": "truffle migrate",
    "dev": "lite-server",
    "build": "npm run compile && npm run migrate"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.0",
    "web3": "^1.8.0",
    "chart.js": "^4.3.0"
  },
  "devDependencies": {
    "truffle": "^5.8.0",
    "lite-server": "^2.6.1"
  }
}