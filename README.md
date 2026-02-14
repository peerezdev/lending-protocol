# Lending & Borrowing Protocol

Decentralized lending and borrowing protocol with multi-asset support and static price oracle implemented in Solidity.

## 📋 Overview

This project implements a decentralized finance (DeFi) protocol that enables users to lend and borrow digital assets in a permissionless manner. The protocol supports multiple asset markets, collateral-based borrowing, automated liquidations, and health factor monitoring. It's designed with security-first principles, incorporating pausability, reentrancy guards, and ownership controls.

## ✨ Features

- ✅ Multi-asset lending markets
- ✅ Collateral-based borrowing system
- ✅ Configurable Loan-to-Value (LTV) ratios per market
- ✅ Health factor monitoring for position safety
- ✅ Automated liquidation mechanism
- ✅ Supply and borrow caps per market
- ✅ Pausable operations for emergency situations
- ✅ Static price oracle integration
- ✅ Comprehensive event system for tracking
- ✅ Owner-controlled market creation and management

## 🏗️ Smart Contract Architecture

### LendingProtocol.sol

Main contract that manages lending, borrowing, and liquidation operations.

**Inheritance:**
- `Ownable`: Access control for administrative functions
- `Pausable`: Emergency pause mechanism
- `ReentrancyGuard`: Protection against reentrancy attacks

**Key Constants:**
```solidity
uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% in basis points
uint256 public constant BASIS_POINTS = 10000;
```

**Data Structures:**

```solidity
struct Market {
    address asset;           // ERC20 token address
    uint256 totalSupply;     // Total amount supplied to the market
    uint256 totalBorrowed;   // Total amount borrowed from the market
    uint256 supplyCap;       // Maximum supply allowed
    uint256 borrowCap;       // Maximum borrow allowed
    uint256 ltv;            // Loan-to-Value ratio (0 = not collateral)
    bool isActive;          // Market activation status
    uint256 staticPrice;    // Asset price in USD
}

struct UserData {
    mapping(bytes32 => uint256) totalSupplied;    // User's supply per market
    mapping(bytes32 => uint256) totalBorrowed;    // User's borrow per market
    uint256 lastUpdateTime;                       // Last interaction timestamp
    EnumerableSet.Bytes32Set collateralMarkets;   // Markets used as collateral
    EnumerableSet.Bytes32Set borrowMarkets;       // Markets with active borrows
}
```

**Core Functions:**

### Administrative Functions

```solidity
function createMarket(
    string memory _marketName,
    address _asset,
    uint256 _supplyCap,
    uint256 _borrowCap,
    uint256 _ltv,
    uint256 _staticPrice
) external onlyOwner whenNotPaused nonReentrant
```
Creates a new lending market with specified parameters. Only callable by the contract owner.

**Parameters:**
- `_marketName`: Unique identifier name for the market
- `_asset`: ERC20 token address
- `_supplyCap`: Maximum total supply allowed in the market
- `_borrowCap`: Maximum total borrow allowed in the market
- `_ltv`: Loan-to-Value ratio in basis points (0-10000)
- `_staticPrice`: Initial price of the asset in USD

```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```
Emergency pause/unpause protocol operations.

### User Functions

```solidity
function lend(bytes32 _marketId, uint256 _amount) external whenNotPaused nonReentrant activeMarket
```
Deposit assets into a market to earn interest and provide liquidity.

```solidity
function withdraw(bytes32 _marketId, uint256 _amount) external whenNotPaused nonReentrant activeMarket
```
Withdraw previously supplied assets. Checks health factor before allowing withdrawal.

```solidity
function borrow(bytes32 _marketId, uint256 _amount) external whenNotPaused nonReentrant activeMarket
```
Borrow assets against supplied collateral. Requires health factor > 1.

```solidity
function repay(bytes32 _marketId, uint256 _amount) external whenNotPaused nonReentrant activeMarket
```
Repay borrowed assets to reduce debt and improve health factor.

```solidity
function liquidate(address _userAddress) external whenNotPaused nonReentrant
```
Liquidate an undercollateralized position. Callable by anyone when health factor < 1.

### View Functions

```solidity
function getCollateralUsd(address _userAddress) public view 
    returns (uint256 _totalCollateral, uint256 _totalUsable, uint256 _totalBorrowed)
```
Calculate user's total collateral value, usable collateral, and total borrowed amount in USD.

```solidity
function getHealthFactor(address _userAddress, uint256 _newWithdrawAmount, uint256 _newBorrowAmount) 
    public view returns (uint256 _healthFactor)
```
Calculate user's health factor. Returns:
- `> 1`: Position is healthy
- `= 1`: Position is at liquidation threshold
- `< 1`: Position can be liquidated
- `0`: No collateral available

```solidity
function getUserDepositForMarket(address _user, bytes32 _marketId) external view returns (uint256)
function getUserBorrowForMarket(address _user, bytes32 _marketId) external view returns (uint256)
```
Query user's deposit or borrow amount for a specific market.

```solidity
function encodeMarketIdentifier(string memory _marketName, address _asset) public pure returns (bytes32)
```
Generate unique market identifier from name and asset address.

## 📝 Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `MarketCreated` | `marketId`, `marketName`, `asset`, `supplyCap`, `borrowCap` | Emitted when a new market is created |
| `MarketUpdated` | `marketId`, `marketName`, `asset`, `supplyCap`, `borrowCap` | Emitted when market parameters are updated |
| `Deposit` | `marketId`, `depositor`, `amount` | Emitted when user deposits assets |
| `Withdraw` | `marketId`, `withdrawer`, `amount` | Emitted when user withdraws assets |
| `Borrow` | `marketId`, `borrower`, `amount` | Emitted when user borrows assets |
| `Repay` | `marketId`, `repayer`, `amount` | Emitted when user repays debt |
| `Liquidate` | `liquidator`, `user` | Emitted when a position is liquidated |

## 🚀 Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git installed
- Basic understanding of Solidity and DeFi concepts

### Installation Steps

1. **Clone the repository:**
```bash
git clone <repository-url>
cd lending-borrowing-protocol
```

2. **Install dependencies:**
```bash
forge install
```

This will install:
- OpenZeppelin Contracts
- Forge Standard Library

3. **Verify installation:**
```bash
forge build
```

## 🧪 Usage Guide

### Building the Project

Compile all contracts:
```bash
forge build
```

Clean and rebuild:
```bash
forge clean && forge build
```

### Running Tests

Run all tests:
```bash
forge test
```

Run tests with verbose output:
```bash
forge test -vvv
```

Run specific test:
```bash
forge test --match-test testLend
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

Run tests with coverage:
```bash
forge coverage
```

### Local Development

Start a local Anvil node:
```bash
anvil
```

Deploy to local network:
```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Deployment

Deploy to testnet (example: Sepolia):
```bash
forge script script/Deploy.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### Interacting with the Contract

Create a market:
```bash
cast send <CONTRACT_ADDRESS> "createMarket(string,address,uint256,uint256,uint256,uint256)" \
    "ETH Market" \
    <TOKEN_ADDRESS> \
    1000000000000000000000 \
    500000000000000000000 \
    7500 \
    2000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

Lend assets:
```bash
cast send <CONTRACT_ADDRESS> "lend(bytes32,uint256)" \
    <MARKET_ID> \
    1000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

Check health factor:
```bash
cast call <CONTRACT_ADDRESS> "getHealthFactor(address,uint256,uint256)" \
    <USER_ADDRESS> \
    0 \
    0 \
    --rpc-url $RPC_URL
```

## ⚙️ Configuration

### Market Configuration

When creating a market, configure the following parameters:

| Parameter | Description | Recommended Values |
|-----------|-------------|-------------------|
| `marketName` | Unique identifier (combined with asset address) | "USDC Market", "ETH Market" |
| `asset` | ERC20 token address | Valid ERC20 contract address |
| `supplyCap` | Maximum total supply | Based on market size (e.g., 1,000,000 tokens) |
| `borrowCap` | Maximum total borrow | 50-80% of supply cap |
| `ltv` | Loan-to-Value ratio (basis points) | 5000-8000 (50%-80%) |
| `staticPrice` | Asset price in USD | Current market price |

### LTV Ratio Guidelines

- **Stablecoins (USDC, USDT, DAI)**: 8000-9000 (80%-90%)
- **Major cryptocurrencies (ETH, BTC)**: 7000-8000 (70%-80%)
- **Volatile assets**: 5000-7000 (50%-70%)
- **Non-collateral assets**: 0 (cannot be used as collateral)

### Foundry Configuration

Customize `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
optimizer = true
optimizer_runs = 200

[profile.ci]
verbosity = 4

[fuzz]
runs = 256

[invariant]
runs = 256
depth = 15
```

## 🛡️ Security Considerations

### Built-in Security Features

1. **Reentrancy Protection**: All state-changing functions use `nonReentrant` modifier
2. **Access Control**: Administrative functions restricted to contract owner
3. **Emergency Pause**: Protocol can be paused in case of emergency
4. **SafeERC20**: Protection against non-standard ERC20 implementations
5. **Health Factor Checks**: Prevents undercollateralized positions

### Important Security Notes

⚠️ **Price Oracle Limitation**: This implementation uses static prices. For production:
- Integrate Chainlink Price Feeds or similar oracle solution
- Implement price update mechanisms with proper access controls
- Add price staleness checks

⚠️ **Testing**: 
- Thoroughly test all edge cases
- Perform professional security audit before mainnet deployment
- Test liquidation mechanisms under various market conditions

⚠️ **Market Parameters**:
- Set conservative supply/borrow caps initially
- Monitor market utilization rates
- Adjust LTV ratios based on asset volatility

⚠️ **Liquidation Risks**:
- Current implementation transfers all collateral to liquidator
- Consider implementing partial liquidations for better UX
- Add liquidation incentive mechanisms

### Known Limitations

1. **No Interest Accrual**: Current version doesn't calculate interest over time
2. **Static Pricing**: Prices need manual updates (not suitable for production)
3. **No Flash Loan Protection**: Additional checks may be needed
4. **Full Liquidation**: Users lose all collateral when liquidated

### Recommended Improvements

- [ ] Implement dynamic interest rate models
- [ ] Integrate decentralized price oracles
- [ ] Add partial liquidation mechanism
- [ ] Implement reserves and protocol fees
- [ ] Add governance mechanisms
- [ ] Create liquidation incentive structure

## 🛠️ Technology Stack

- **Solidity**: 0.8.30
- **Foundry**: Development framework and testing suite
- **OpenZeppelin Contracts**: 
  - `Ownable`: Access control
  - `Pausable`: Emergency mechanisms
  - `ReentrancyGuard`: Security protection
  - `SafeERC20`: Safe token interactions
  - `EnumerableSet`: Efficient set operations
- **Forge Std**: Testing utilities and cheats

## 📄 License

MIT

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📧 Contact

For questions and support, please open an issue in the repository.

---

**Disclaimer**: This code is provided as-is for educational purposes. It has not been audited and should not be used in production without proper security review and testing.
