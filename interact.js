const hre = require("hardhat");

function resolveAddress() {
    return process.env.DAO_GOVERNOR_ADDRESS || process.env.CONTRACT_ADDRESS || process.env.DEPLOYED_CONTRACT_ADDRESS || "";
}

async function main() {
    const contractAddress = resolveAddress();

    if (!contractAddress) {
        throw new Error("Set DAO_GOVERNOR_ADDRESS or CONTRACT_ADDRESS before running this script.");
    }

    const governor = await hre.ethers.getContractAt("DAOGovernor", contractAddress);
    const votingDelay = await governor.votingDelay();
    const votingPeriod = await governor.votingPeriod();

    console.log("DAO Governance System contract:", contractAddress);
    console.log("Voting delay:", votingDelay.toString());
    console.log("Voting period:", votingPeriod.toString());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
