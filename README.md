# HedgeVault

A sophisticated DeFi lending protocol built on the Stacks blockchain with integrated risk hedging mechanisms and derivative protection. HedgeVault allows users to lend and borrow STX with automated risk management, collateral hedging, and derivative-based downside protection.

## 🚀 Features

### Core Lending & Borrowing
- **Deposit STX**: Earn yield by providing liquidity to the protocol
- **Collateralized Loans**: Borrow STX against collateral with competitive rates
- **Automated Interest Calculation**: Dynamic interest accrual based on utilization
- **Liquidation Protection**: Automated liquidation of undercollateralized positions

### Advanced Risk Management
- **Integrated Hedging**: Create derivative positions to protect against downside risk
- **Strike Price Protection**: Set custom strike prices for hedge positions
- **Premium-based Hedging**: Pay premiums for downside protection
- **Exercise Options**: Exercise profitable hedge positions automatically

### Protocol Features
- **HVault Tokens**: Receive yield-bearing tokens representing deposits
- **Oracle Integration**: Real-time price feeds for accurate valuations
- **Emergency Controls**: Protocol-level pause mechanisms for security
- **Liquidation Incentives**: 5% bonus rewards for liquidators

## 📊 Technical Specifications

### Smart Contract Details
- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Token Standard**: SIP-010 (Fungible Token)
- **Epoch**: 2.5

### Key Parameters
- **Minimum Collateral Ratio**: 150%
- **Liquidation Threshold**: 120%
- **Maximum LTV**: 80%
- **Base Interest Rate**: 5% annual
- **Hedge Fee**: 1%
- **Protocol Fee**: 2%
- **Liquidation Bonus**: 5%

### Supported Assets
- **Primary**: STX (Stacks Token)
- **Collateral**: STX
- **Yield Token**: hvault-token

## 🛠️ Installation

### Prerequisites
- [Clarinet CLI](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v18+
- [Stacks CLI](https://github.com/blockstack/stacks-blockchain)

### Setup
1. Clone the repository:
```bash
git clone <repository-url>
cd HedgeVault
```

2. Navigate to the contract directory:
```bash
cd HedgeVault_contract
```

3. Install dependencies:
```bash
npm install
```

4. Initialize Clarinet project:
```bash
clarinet check
```

## 🎯 Usage Examples

### Depositing STX
```clarity
;; Deposit 1000 STX to earn yield
(contract-call? .HedgeVault deposit u1000000000)
```

### Creating a Loan
```clarity
;; Create loan: borrow 500 STX with 1000 STX collateral
(contract-call? .HedgeVault create-loan u500000000 u1000000000)
```

### Creating a Hedge Position
```clarity
;; Create hedge for loan ID 1: protect 800 STX at strike price $25 for 1000 blocks
(contract-call? .HedgeVault create-hedge u1 u800000000 u25000000 u1000)
```

### Withdrawing Funds
```clarity
;; Withdraw 500 hvault tokens
(contract-call? .HedgeVault withdraw u500000000)
```

## 📋 Contract Functions

### Public Functions

#### Core Operations
- `initialize()` - Initialize the contract (owner only)
- `deposit(amount)` - Deposit STX to earn yield
- `withdraw(hvault-amount)` - Withdraw deposited STX plus interest
- `create-loan(loan-amount, collateral-amount)` - Create collateralized loan
- `repay-loan(loan-id)` - Repay loan with interest

#### Risk Management
- `create-hedge(loan-id, hedge-amount, strike-price, duration-blocks)` - Create hedge position
- `exercise-hedge(hedge-id)` - Exercise profitable hedge
- `liquidate-loan(loan-id)` - Liquidate undercollateralized loan

#### Administrative
- `set-emergency-pause(paused)` - Emergency protocol pause (owner only)
- `update-price(asset, price)` - Update oracle price (owner only)

### Read-Only Functions
- `get-user-deposit(user)` - Get user's deposit balance
- `get-user-borrowed(user)` - Get user's borrowed amount
- `get-user-collateral(user)` - Get user's collateral amount
- `get-hvault-balance(user)` - Get user's hvault token balance
- `get-loan(loan-id)` - Get loan details
- `get-hedge(hedge-id)` - Get hedge position details
- `get-protocol-stats()` - Get protocol statistics
- `get-asset-price(asset)` - Get current asset price

## 🚀 Deployment Guide

### Local Development
1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy and initialize:
```clarity
(contract-call? .HedgeVault initialize)
```

### Testnet Deployment
1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

### Mainnet Deployment
1. Update `settings/Mainnet.toml` with production parameters
2. Deploy to mainnet:
```bash
clarinet deployments generate --mainnet
clarinet deployments apply --mainnet
```

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Run tests with coverage:
```bash
npm run test:report
```

Watch mode for development:
```bash
npm run test:watch
```

## 🔒 Security Considerations

### Smart Contract Security
- **Reentrancy Protection**: Built-in protection through Clarity's design
- **Integer Overflow**: Clarity prevents overflow/underflow vulnerabilities
- **Access Controls**: Owner-only functions properly restricted
- **Emergency Pause**: Protocol can be paused in emergencies

### Risk Factors
- **Oracle Dependency**: Price feeds are critical for accurate valuations
- **Liquidation Risk**: Positions may be liquidated during market volatility
- **Smart Contract Risk**: Code audits recommended before mainnet deployment
- **Collateral Risk**: STX price volatility affects collateral value

### Best Practices
- Always maintain adequate collateralization ratios
- Monitor positions during high volatility periods
- Use hedging features to protect against downside risk
- Keep emergency pause functionality accessible

## 🏗️ Architecture

### Contract Structure
```
HedgeVault.clar
├── Token Definitions (hvault-token)
├── Constants & Error Codes
├── Data Variables & Maps
├── Public Functions
│   ├── Core Operations
│   ├── Risk Management
│   └── Administrative
├── Read-Only Functions
└── Private Helper Functions
```

### Data Models
- **Loans**: Borrower, amount, collateral, interest rate, timestamps
- **Hedges**: User, loan ID, hedge parameters, expiry, premium
- **User Balances**: Deposits, borrowed amounts, collateral, hvault tokens

## 📈 Protocol Statistics

The contract tracks key metrics:
- Total STX supplied to the protocol
- Total STX borrowed from the protocol
- Utilization rate (borrowed/supplied)
- Number of active loans and hedges
- Individual user positions and balances

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the ISC License.

## 📞 Support

For questions, issues, or contributions:
- Create an issue in the repository
- Join our community discussions
- Review the documentation and code comments

---

**Disclaimer**: This is experimental DeFi software. Use at your own risk. Smart contracts have not been audited. Always test thoroughly on testnet before mainnet deployment.