// Web3 and Contract Configuration
let web3;
let userAccount;
let governanceContract;
let ticketContract;
let tokenContract;

// Contract addresses (Update with your deployed contracts)
const CONTRACT_ADDRESSES = {
    governance: '0x...', // Your AlGovernanceAgent address
    ticket: '0x...',    // Your EventTicketNFT address
    token: '0x...'       // Your GovernanceToken address
};

// Application State
let proposals = [];
let tickets = [];
let userVotingPower = 0;
let charts = {};

// Initialize Application
document.addEventListener('DOMContentLoaded', async () => {
    await initializeWeb3();
    setupEventListeners();
    loadSampleData();
    initializeCharts();
});

async function initializeWeb3() {
    if (window.ethereum) {
        web3 = new Web3(window.ethereum);
        await connectWallet();
    } else {
        showToast('Please install MetaMask!', 'error');
    }
}

async function connectWallet() {
    try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        userAccount = accounts[0];
        document.getElementById('connectWallet').innerHTML = `
            <i class="fas fa-wallet"></i> 
            ${userAccount.substring(0, 6)}...${userAccount.substring(38)}
        `;
        await getUserVotingPower();
        await loadProposals();
        await loadTickets();
        updateDashboard();
        showToast('Wallet connected successfully!', 'success');
    } catch (error) {
        console.error('Error connecting wallet:', error);
        showToast('Failed to connect wallet', 'error');
    }
}

async function getUserVotingPower() {
    // Simulate getting voting power from GovernanceToken contract
    userVotingPower = Math.floor(Math.random() * 1000) + 100;
    document.getElementById('votingPower').textContent = userVotingPower;
    return userVotingPower;
}

function loadSampleData() {
    // Sample proposals
    proposals = [
        {
            id: 1,
            title: "Increase Event Budget",
            description: "Proposal to increase the budget for the annual conference",
            status: "active",
            votesFor: 1250,
            votesAgainst: 450,
            endTime: Date.now() + 7 * 24 * 60 * 60 * 1000,
            type: "funding",
            amount: 50
        },
        {
            id: 2,
            title: "New Event Venue",
            description: "Select a new venue for upcoming events",
            status: "active",
            votesFor: 980,
            votesAgainst: 320,
            endTime: Date.now() + 5 * 24 * 60 * 60 * 1000,
            type: "event"
        },
        {
            id: 3,
            title: "DAO Parameter Update",
            description: "Update voting threshold and quorum requirements",
            status: "pending",
            votesFor: 0,
            votesAgainst: 0,
            endTime: Date.now() + 3 * 24 * 60 * 60 * 1000,
            type: "parameter"
        }
    ];
    
    // Sample tickets
    tickets = [
        {
            id: 1,
            name: "VIP Conference Pass",
            event: "Web3 Summit 2024",
            price: "0.5 ETH",
            available: 50,
            image: "🎫",
            benefits: ["Front Row Access", "Meet & Greet", "Exclusive Merch"]
        },
        {
            id: 2,
            name: "Early Bird Ticket",
            event: "NFT Expo",
            price: "0.2 ETH",
            available: 100,
            image: "🎟️",
            benefits: ["Early Access", "Workshop Entry"]
        },
        {
            id: 3,
            name: "DAO Member Pass",
            event: "Governance Workshop",
            price: "0.3 ETH",
            available: 75,
            image: "🎫",
            benefits: ["Voting Rights", "Proposal Access"]
        }
    ];
}

function updateDashboard() {
    document.getElementById('totalMembers').textContent = Math.floor(Math.random() * 500) + 200;
    document.getElementById('totalProposals').textContent = proposals.length;
    document.getElementById('totalTickets').textContent = tickets.length * 50;
    document.getElementById('totalValue').textContent = `$${(Math.random() * 100000 + 50000).toFixed(0)}`;
    
    displayActiveProposals();
    displayProposals();
    displayTickets();
}

function displayActiveProposals() {
    const activeProposals = proposals.filter(p => p.status === 'active');
    const container = document.getElementById('activeProposalsList');
    
    if (activeProposals.length === 0) {
        container.innerHTML = '<p class="placeholder">No active proposals</p>';
        return;
    }
    
    container.innerHTML = activeProposals.map(proposal => `
        <div class="proposal-item">
            <h4>${proposal.title}</h4>
            <p>${proposal.description.substring(0, 100)}...</p>
            <div class="vote-info">
                <span>👍 ${proposal.votesFor}</span>
                <span>👎 ${proposal.votesAgainst}</span>
            </div>
            <button onclick="voteOnProposal(${proposal.id})" class="btn-secondary">
                Vote Now
            </button>
        </div>
    `).join('');
}

function displayProposals() {
    const container = document.getElementById('proposalsContainer');
    
    container.innerHTML = proposals.map(proposal => {
        const totalVotes = proposal.votesFor + proposal.votesAgainst;
        const forPercentage = totalVotes > 0 ? (proposal.votesFor / totalVotes) * 100 : 0;
        const timeLeft = Math.max(0, proposal.endTime - Date.now());
        const daysLeft = Math.ceil(timeLeft / (1000 * 60 * 60 * 24));
        
        return `
            <div class="proposal-card">
                <div class="proposal-header">
                    <h3>${proposal.title}</h3>
                    <span class="proposal-status status-${proposal.status}">${proposal.status.toUpperCase()}</span>
                </div>
                <p>${proposal.description}</p>
                ${proposal.amount ? `<p><strong>Amount:</strong> ${proposal.amount} ETH</p>` : ''}
                <div class="vote-progress">
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${forPercentage}%"></div>
                    </div>
                    <div class="vote-stats">
                        <span>For: ${proposal.votesFor}</span>
                        <span>Against: ${proposal.votesAgainst}</span>
                    </div>
                </div>
                <div class="vote-buttons">
                    <button onclick="voteOnProposal(${proposal.id}, true)" class="btn-primary">
                        <i class="fas fa-thumbs-up"></i> Vote For
                    </button>
                    <button onclick="voteOnProposal(${proposal.id}, false)" class="btn-secondary">
                        <i class="fas fa-thumbs-down"></i> Vote Against
                    </button>
                </div>
                <small>Time left: ${daysLeft} days</small>
            </div>
        `;
    }).join('');
}

function displayTickets() {
    const container = document.getElementById('ticketGrid');
    
    container.innerHTML = tickets.map(ticket => `
        <div class="ticket-card" onclick="purchaseTicket(${ticket.id})">
            <div class="ticket-header">
                <div class="ticket-icon">${ticket.image}</div>
                <div class="ticket-badge">${ticket.available} left</div>
            </div>
            <h3>${ticket.name}</h3>
            <p><strong>Event:</strong> ${ticket.event}</p>
            <p><strong>Price:</strong> ${ticket.price}</p>
            <div class="ticket-benefits">
                <strong>Benefits:</strong>
                <ul>
                    ${ticket.benefits.map(benefit => `<li>${benefit}</li>`).join('')}
                </ul>
            </div>
            <button class="btn-primary w-full mt-2" onclick="event.stopPropagation(); purchaseTicket(${ticket.id})">
                <i class="fas fa-shopping-cart"></i> Purchase Ticket
            </button>
        </div>
    `).join('');
}

async function voteOnProposal(proposalId, voteFor) {
    if (!userAccount) {
        showToast('Please connect your wallet first!', 'warning');
        return;
    }
    
    const proposal = proposals.find(p => p.id === proposalId);
    if (!proposal || proposal.status !== 'active') {
        showToast('This proposal is not active!', 'error');
        return;
    }
    
    if (userVotingPower === 0) {
        showToast('You have no voting power! Get some governance tokens.', 'warning');
        return;
    }
    
    // Simulate voting transaction
    showToast('Processing your vote...', 'info');
    
    setTimeout(() => {
        if (voteFor) {
            proposal.votesFor += userVotingPower;
            showToast(`Voted FOR proposal ${proposalId} with ${userVotingPower} voting power!`, 'success');
        } else {
            proposal.votesAgainst += userVotingPower;
            showToast(`Voted AGAINST proposal ${proposalId} with ${userVotingPower} voting power!`, 'success');
        }
        
        displayProposals();
        displayActiveProposals();
        updateCharts();
    }, 1500);
}

async function createProposal() {
    document.getElementById('proposalModal').style.display = 'block';
}

document.getElementById('proposalForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const title = document.getElementById('proposalTitle').value;
    const description = document.getElementById('proposalDescription').value;
    const amount = document.getElementById('proposalAmount').value;
    const type = document.getElementById('proposalType').value;
    
    const newProposal = {
        id: proposals.length + 1,
        title,
        description,
        status: 'active',
        votesFor: 0,
        votesAgainst: 0,
        endTime: Date.now() + 7 * 24 * 60 * 60 * 1000,
        type,
        amount: amount || null
    };
    
    proposals.unshift(newProposal);
    document.getElementById('proposalModal').style.display = 'none';
    document.getElementById('proposalForm').reset();
    
    updateDashboard();
    showToast('Proposal created successfully!', 'success');
});

async function purchaseTicket(ticketId) {
    if (!userAccount) {
        showToast('Please connect your wallet first!', 'warning');
        return;
    }
    
    const ticket = tickets.find(t => t.id === ticketId);
    if (!ticket || ticket.available === 0) {
        showToast('Ticket not available!', 'error');
        return;
    }
    
    showToast(`Processing purchase of ${ticket.name}...`, 'info');
    
    setTimeout(() => {
        ticket.available--;
        showToast(`Successfully purchased ${ticket.name}! Check your NFT collection.`, 'success');
        displayTickets();
    }, 1500);
}

async function delegateVote() {
    if (!userAccount) {
        showToast('Please connect your wallet first!', 'warning');
        return;
    }
    
    const delegateAddress = prompt('Enter delegate address:', userAccount);
    if (delegateAddress) {
        showToast(`Voting power delegated to ${delegateAddress.substring(0, 6)}...`, 'success');
    }
}

async function mintTicket() {
    if (!userAccount) {
        showToast('Please connect your wallet first!', 'warning');
        return;
    }
    
    const eventName = prompt('Enter event name:');
    const price = prompt('Enter ticket price (ETH):');
    
    if (eventName && price) {
        const newTicket = {
            id: tickets.length + 1,
            name: `${eventName} Ticket`,
            event: eventName,
            price: `${price} ETH`,
            available: 100,
            image: "🎫",
            benefits: ["Standard Access"]
        };
        
        tickets.push(newTicket);
        showToast('New ticket minted successfully!', 'success');
        displayTickets();
        updateDashboard();
    }
}

async function stakeTokens() {
    if (!userAccount) {
        showToast('Please connect your wallet first!', 'warning');
        return;
    }
    
    const amount = prompt('Enter amount of tokens to stake:');
    if (amount && !isNaN(amount)) {
        showToast(`Staking ${amount} tokens...`, 'info');
        setTimeout(() => {
            userVotingPower += parseInt(amount);
            document.getElementById('votingPower').textContent = userVotingPower;
            showToast(`Successfully staked ${amount} tokens!`, 'success');
        }, 1500);
    }
}

function initializeCharts() {
    const ctx1 = document.getElementById('voteChart')?.getContext('2d');
    const ctx2 = document.getElementById('ticketChart')?.getContext('2d');
    
    if (ctx1) {
        charts.voteChart = new Chart(ctx1, {
            type: 'doughnut',
            data: {
                labels: ['For', 'Against'],
                datasets: [{
                    data: [0, 0],
                    backgroundColor: ['#48bb78', '#f56565']
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        labels: { color: 'white' }
                    }
                }
            }
        });
    }
    
    if (ctx2) {
        charts.ticketChart = new Chart(ctx2, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [{
                    label: 'Tickets Sold',
                    data: [65, 89, 120, 145, 210, 280],
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        labels: { color: 'white' }
                    }
                },
                scales: {
                    y: {
                        ticks: { color: 'white' }
                    },
                    x: {
                        ticks: { color: 'white' }
                    }
                }
            }
        });
    }
}

function updateCharts() {
    if (charts.voteChart) {
        const totalFor = proposals.reduce((sum, p) => sum + p.votesFor, 0);
        const totalAgainst = proposals.reduce((sum, p) => sum + p.votesAgainst, 0);
        charts.voteChart.data.datasets[0].data = [totalFor, totalAgainst];
        charts.voteChart.update();
    }
}

function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
        ${message}
    `;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

function setupEventListeners() {
    // Connect wallet button
    document.getElementById('connectWallet')?.addEventListener('click', connectWallet);
    
    // Modal close
    const modal = document.getElementById('proposalModal');
    const closeBtn = document.querySelector('.close');
    
    closeBtn?.addEventListener('click', () => {
        modal.style.display = 'none';
    });
    
    window.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // Smooth scroll for navigation
    document.querySelectorAll('.nav-links a').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            e.preventDefault();
            const target = document.querySelector(anchor.getAttribute('href'));
            target?.scrollIntoView({ behavior: 'smooth' });
        });
    });
}

// Export functions for global access
window.voteOnProposal = voteOnProposal;
window.createProposal = createProposal;
window.purchaseTicket = purchaseTicket;
window.delegateVote = delegateVote;
window.mintTicket = mintTicket;
window.stakeTokens = stakeTokens;