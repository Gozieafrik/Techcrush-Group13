// Web3 Configuration
let web3;
let userAccount;
let governanceTokenContract;
let daoGovernorContract;
let aiAgentContract;
let nftTicketContract;

// Contract Addresses (Update after deployment)
const CONTRACT_ADDRESSES = {
    governanceToken: "0x...",
    daoGovernor: "0x...",
    aiAgent: "0x...",
    nftTicket: "0x...",
    timelock: "0x...",
    treasury: "0x..."
};

// Contract ABIs (Simplified - use full ABIs from compiled contracts)
const ABIS = {
    governanceToken: [
        "function balanceOf(address) view returns (uint256)",
        "function getVotes(address) view returns (uint256)",
        "function delegate(address) external",
        "function mint(address,uint256) external"
    ],
    daoGovernor: [
        "function propose(address[],uint256[],bytes[],string) returns (uint256)",
        "function castVote(uint256,uint8) external",
        "function state(uint256) view returns (uint8)",
        "function proposalVotes(uint256) view returns (uint256,uint256,uint256)"
    ],
    aiAgent: [
        "function analyzeProposal(uint256,string,uint256,string,string,uint256,string[],uint256) external",
        "function getRecommendation(uint256) view returns (string,string,uint256,uint256,string[])",
        "function setVotingPreferences(uint256,bool,address,string[],uint256) external"
    ],
    nftTicket: [
        "function mintTicket(uint256,bool,string) external payable",
        "function getEventDetails(uint256) view returns (string,uint256,uint256,uint256,uint256,bool)",
        "function balanceOf(address) view returns (uint256)"
    ]
};

// Initialize Web3
async function initWeb3() {
    if (window.ethereum) {
        web3 = new Web3(window.ethereum);
        await window.ethereum.request({ method: 'eth_requestAccounts' });
        
        const accounts = await web3.eth.getAccounts();
        userAccount = accounts[0];
        
        document.getElementById('connectWalletBtn').innerHTML = `🟢 ${userAccount.slice(0,6)}...${userAccount.slice(-4)}`;
        document.getElementById('connectWalletBtn').disabled = true;
        
        // Initialize contracts
        initializeContracts();
        
        // Load data
        await loadStats();
        await loadProposals();
        await loadVotingPower();
        
        // Setup event listeners
        setupEventListeners();
        
        console.log("Web3 initialized for:", userAccount);
    } else {
        alert("Please install MetaMask!");
    }
}

function initializeContracts() {
    governanceTokenContract = new web3.eth.Contract(ABIS.governanceToken, CONTRACT_ADDRESSES.governanceToken);
    daoGovernorContract = new web3.eth.Contract(ABIS.daoGovernor, CONTRACT_ADDRESSES.daoGovernor);
    aiAgentContract = new web3.eth.Contract(ABIS.aiAgent, CONTRACT_ADDRESSES.aiAgent);
    nftTicketContract = new web3.eth.Contract(ABIS.nftTicket, CONTRACT_ADDRESSES.nftTicket);
}

async function loadStats() {
    try {
        // Get treasury balance
        const balance = await web3.eth.getBalance(CONTRACT_ADDRESSES.treasury);
        const ethBalance = web3.utils.fromWei(balance, 'ether');
        document.getElementById('treasuryBalance').innerHTML = `${parseFloat(ethBalance).toFixed(2)} ETH`;
        
        // Get proposal count (mock - implement actual)
        document.getElementById('totalProposals').innerHTML = "12";
        document.getElementById('activeProposals').innerHTML = "3";
        document.getElementById('totalVotes').innerHTML = "847";
    } catch (error) {
        console.error("Error loading stats:", error);
    }
}

async function loadProposals() {
    const proposalsList = document.getElementById('proposalsList');
    const proposalSelect = document.getElementById('proposalSelect');
    
    // Mock proposals - replace with actual contract calls
    const proposals = [
        { id: 1, title: "Fund Governance Development", status: "Active", risk: "Low" },
        { id: 2, title: "Treasury Diversification", status: "Active", risk: "Medium" },
        { id: 3, title: "New Partnership Agreement", status: "Voting", risk: "High" }
    ];
    
    proposalsList.innerHTML = proposals.map(p => `
        <div class="proposal-item" onclick="selectProposal(${p.id})">
            <strong>#${p.id}</strong> ${p.title}<br>
            <span class="risk-${p.risk.toLowerCase()}">⚠️ ${p.risk} Risk</span>
            <span style="margin-left: 10px;">📊 ${p.status}</span>
        </div>
    `).join('');
    
    proposalSelect.innerHTML = '<option>Select a proposal</option>' + 
        proposals.map(p => `<option value="${p.id}">#${p.id}: ${p.title}</option>`).join('');
}

async function selectProposal(proposalId) {
    try {
        // Get governance recommendation
        const recommendation = await aiAgentContract.methods.getRecommendation(proposalId).call();
        
        document.getElementById('governanceRecommendation').innerHTML = `
            <div class="recommendation">🤖 Governance Recommendation: ${recommendation[0]}</div>
            <div><strong>Confidence:</strong> ${recommendation[2]}%</div>
            <div><strong>Risk Score:</strong> ${recommendation[3]}/100</div>
            <div><strong>Reasoning:</strong> ${recommendation[1]}</div>
            <div><strong>Risk Factors:</strong> ${recommendation[4].join(', ')}</div>
        `;
        
        document.getElementById('runGovernanceAnalysisBtn').disabled = false;
        document.getElementById('runGovernanceAnalysisBtn').onclick = () => runGovernanceAnalysis(proposalId);
        
    } catch (error) {
        console.log("No governance analysis yet for this proposal");
        document.getElementById('governanceRecommendation').innerHTML = `
            <div class="recommendation">🤔 Run Governance Analysis</div>
            <div>Click "Run Governance Analysis" to get intelligent recommendations</div>
        `;
    }
}

async function runGovernanceAnalysis(proposalId) {
    document.getElementById('governanceAnalysis').innerHTML = '<div class="loader"></div> Analyzing...';
    
    // Simulate governance analysis
    setTimeout(() => {
        const analysis = {
            summary: "This proposal aims to allocate 100 ETH to the DAO governance development fund",
            riskScore: 25,
            recommendation: "FOR",
            reasoning: "Strong alignment with DAO goals and a positive governance outlook",
            confidence: 85,
            riskFactors: ["Technical complexity", "Implementation timeline"],
            dcfValue: 250000
        };
        
        document.getElementById('governanceRecommendation').innerHTML = `
            <div class="recommendation">🤖 Governance Recommendation: ${analysis.recommendation}</div>
            <div><strong>Confidence:</strong> ${analysis.confidence}%</div>
            <div><strong>Risk Score:</strong> ${analysis.riskScore}/100</div>
            <div><strong>DCF Value:</strong> ${analysis.dcfValue} ETH</div>
            <div><strong>Reasoning:</strong> ${analysis.reasoning}</div>
            <div><strong>Risk Factors:</strong> ${analysis.riskFactors.join(', ')}</div>
            <button onclick="autoVoteBasedOnGovernanceAnalysis(${proposalId})" style="margin-top: 10px;">🤖 Auto-Vote with Governance Analysis</button>
        `;
        
    }, 2000);
}

async function autoVoteBasedOnGovernanceAnalysis(proposalId) {
    try {
        const recommendation = await aiAgentContract.methods.getRecommendation(proposalId).call();
        
        let voteValue = 0; // 0=Against, 1=For, 2=Abstain
        if (recommendation[0] === "FOR") voteValue = 1;
        else if (recommendation[0] === "AGAINST") voteValue = 0;
        else voteValue = 2;
        
        await daoGovernorContract.methods.castVote(proposalId, voteValue).send({ from: userAccount });
        alert(`Auto-voted ${recommendation[0]} on proposal ${proposalId}!`);
        
    } catch (error) {
        console.error("Auto-vote failed:", error);
        alert("Auto-vote failed. You may need more voting power.");
    }
}

async function loadVotingPower() {
    try {
        const votes = await governanceTokenContract.methods.getVotes(userAccount).call();
        const formattedVotes = web3.utils.fromWei(votes, 'ether');
        document.getElementById('votingPower').innerHTML = `🗳️ Your Voting Power: ${formattedVotes} GOV`;
    } catch (error) {
        console.error("Error loading voting power:", error);
        document.getElementById('votingPower').innerHTML = `🗳️ Voting Power: Connect wallet to see`;
    }
}

async function mintNFTTicket() {
    const eventId = document.getElementById('eventId').value;
    const price = document.getElementById('ticketPrice').value;
    const priceWei = web3.utils.toWei(price, 'ether');
    
    try {
        await nftTicketContract.methods.mintTicket(eventId, false, "A1").send({
            from: userAccount,
            value: priceWei
        });
        alert("NFT Ticket minted successfully!");
        document.getElementById('ticketStatus').innerHTML = "✅ Ticket minted! Check your wallet.";
    } catch (error) {
        console.error("Minting failed:", error);
        document.getElementById('ticketStatus').innerHTML = "❌ Minting failed: " + error.message;
    }
}

async function createProposal() {
    const title = document.getElementById('proposalTitle').value;
    const description = document.getElementById('proposalDesc').value;
    const target = document.getElementById('proposalTarget').value;
    const value = document.getElementById('proposalValue').value;
    
    const targets = [target];
    const values = [web3.utils.toWei(value, 'ether')];
    const calldatas = ["0x"];
    
    try {
        await daoGovernorContract.methods.propose(targets, values, calldatas, description).send({
            from: userAccount
        });
        alert("Proposal created successfully!");
        document.getElementById('proposalModal').style.display = 'none';
        await loadProposals();
    } catch (error) {
        console.error("Proposal creation failed:", error);
        alert("Proposal creation failed: " + error.message);
    }
}

function setupEventListeners() {
    document.getElementById('voteForBtn').onclick = async () => {
        const proposalId = document.getElementById('proposalSelect').value;
        if (proposalId && proposalId !== "Select a proposal") {
            await daoGovernorContract.methods.castVote(proposalId, 1).send({ from: userAccount });
            alert(`Voted FOR on proposal ${proposalId}`);
        }
    };
    
    document.getElementById('voteAgainstBtn').onclick = async () => {
        const proposalId = document.getElementById('proposalSelect').value;
        if (proposalId && proposalId !== "Select a proposal") {
            await daoGovernorContract.methods.castVote(proposalId, 0).send({ from: userAccount });
            alert(`Voted AGAINST on proposal ${proposalId}`);
        }
    };
    
    document.getElementById('voteAbstainBtn').onclick = async () => {
        const proposalId = document.getElementById('proposalSelect').value;
        if (proposalId && proposalId !== "Select a proposal") {
            await daoGovernorContract.methods.castVote(proposalId, 2).send({ from: userAccount });
            alert(`Abstained on proposal ${proposalId}`);
        }
    };
    
    document.getElementById('mintTicketBtn').onclick = mintNFTTicket;
    document.getElementById('createProposalBtn').onclick = () => {
        document.getElementById('proposalModal').style.display = 'flex';
    };
    document.getElementById('submitProposalBtn').onclick = createProposal;
    document.getElementById('closeModalBtn').onclick = () => {
        document.getElementById('proposalModal').style.display = 'none';
    };
}

// Initialize on load
window.addEventListener('load', () => {
    document.title = 'DAO Governance System';
    document.getElementById('connectWalletBtn').onclick = initWeb3;
});