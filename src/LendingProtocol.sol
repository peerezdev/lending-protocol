// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingProtocol is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% in basis points
    uint256 public constant BASIS_POINTS = 10000;

    struct Market {
        address asset;
        uint256 totalSupply;
        uint256 totalBorrowed;
        uint256 supplyCap;
        uint256 borrowCap;
        uint256 ltv; // 0 -> can not be used as collateral
        bool isActive;
        uint256 staticPrice;
    }

    struct UserData {
        mapping(bytes32 => uint256) totalSupplied;
        mapping(bytes32 => uint256) totalBorrowed;
        uint256 lastUpdateTime;
        EnumerableSet.Bytes32Set collateralMarkets;
        EnumerableSet.Bytes32Set borrowMarkets;
    }

    mapping(bytes32 => Market) public markets;
    mapping(address => UserData) usersData;

    event MarketCreated(bytes32 indexed marketId, string indexed marketName, address indexed asset, uint256 supplyCap, uint256 borrowCap);
    event MarketUpdated(bytes32 indexed marketId, string indexed marketName, address indexed asset, uint256 supplyCap, uint256 borrowCap);
    event Deposit(bytes32 indexed marketId, address indexed depositor, uint256 amount);
    event Withdraw(bytes32 indexed marketId, address indexed withdrawer, uint256 amount);
    event Borrow(bytes32 indexed marketId, address indexed borrower, uint256 amount);
    event Repay(bytes32 indexed marketId, address indexed repayer, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user);

    constructor() Ownable(msg.sender) { }

    modifier activeMarket(bytes32 _marketId) {
        require(markets[_marketId].isActive, "Market not active or not exists");
        _;
    }

    function pause() external onlyOwner() {
        _pause();
    }

    function unpause() external onlyOwner() {
        _unpause();
    }

    function encodeMarketIdentifier(string memory _marketName, address _asset) public pure returns (bytes32 _marketId) {
        _marketId = keccak256(abi.encode(_marketName, _asset));
    }

    function createMarket(string memory _marketName, address _asset, uint256 _supplyCap, uint256 _borrowCap, uint256 _ltv, uint256 _staticPrice) external onlyOwner() whenNotPaused() nonReentrant() {
        bytes32 _marketId = encodeMarketIdentifier(_marketName, _asset);
        require(markets[_marketId].supplyCap == 0, "Market already exists");
        require(bytes(_marketName).length > 0, "Market name can not be empty");
        require(_asset != address(0), "Invalid asset");
        require(_supplyCap > 0, "Supply cap can not be zero");
        require(_borrowCap > 0, "Borrow cap can not be zero");
        require(_ltv < BASIS_POINTS, "LTV can not be greater than BASIS_POINTS");
        require(_staticPrice > 0, "Static price can not be zero");

        Market storage _market = markets[_marketId];
        
        _market.asset = _asset;
        _market.supplyCap = _supplyCap;
        _market.borrowCap = _borrowCap;
        _market.ltv = _ltv;
        _market.isActive = true;
        _market.staticPrice = _staticPrice;
        emit MarketCreated(_marketId, _marketName, _asset, _supplyCap, _borrowCap);
    }

    function lend(bytes32 _marketId, uint256 _amount) external whenNotPaused() nonReentrant() activeMarket(_marketId) {
        UserData storage _user = usersData[msg.sender];
        Market storage _market = markets[_marketId];
        
        require(_amount > 0, "Amount can not be zero");
        require(_market.totalSupply + _amount <= _market.supplyCap, "Supply cap exceeded");

        _user.totalSupplied[_marketId] += _amount;
        _user.lastUpdateTime = block.timestamp;
        if (_market.ltv > 0) {
            _user.collateralMarkets.add(_marketId);
        }
        _market.totalSupply += _amount;

        IERC20(_market.asset).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(_marketId, msg.sender, _amount);
    }

    function withdraw(bytes32 _marketId, uint256 _amount) external whenNotPaused() nonReentrant() activeMarket(_marketId) {
        require(_amount > 0, "Amount can not be zero");
        UserData storage _user = usersData[msg.sender];
        require(_user.totalSupplied[_marketId] >= _amount, "Not enough supplied in this market");

        Market storage _market = markets[_marketId];        
        uint256 _assetPrice = _market.staticPrice;
        uint256 _withdrawInUsd = _amount * _assetPrice;
        uint256 _healthFactor = getHealthFactor(msg.sender, _withdrawInUsd, 0);
        require(_healthFactor > 0, "Not enough collateral to withdraw");


        _user.totalSupplied[_marketId] -= _amount;
        _user.lastUpdateTime = block.timestamp;
        if (_user.totalSupplied[_marketId] == 0) {
            _user.collateralMarkets.remove(_marketId);
        }
        _market.totalSupply -= _amount;
        IERC20(_market.asset).safeTransfer(msg.sender, _amount);

        emit Withdraw(_marketId, msg.sender, _amount);
    }

    function getCollateralUsd(address _userAddress) public view returns (uint256 _totalCollateral, uint256 _totalUsable, uint256 _totalBorrowed){
        UserData storage _user = usersData[_userAddress];

        for (uint256 i = 0; i < _user.collateralMarkets.length(); i++) {
            bytes32 _marketId = _user.collateralMarkets.at(i);
            uint256 _suppliedMarket = _user.totalSupplied[_marketId];
            if (_suppliedMarket > 0) {
                uint256 _assetPrice = markets[_marketId].staticPrice;
                uint256 _suppliedMarketInUsd = _suppliedMarket * _assetPrice;
                _totalCollateral += _suppliedMarketInUsd;
                _totalUsable += _suppliedMarketInUsd * markets[_marketId].ltv / BASIS_POINTS;
            }
        }

        for (uint256 i = 0; i < _user.borrowMarkets.length(); i++) {
            bytes32 _marketId = _user.borrowMarkets.at(i);
            uint256 _borrowedMarket = _user.totalBorrowed[_marketId];
            if (_borrowedMarket > 0) {
                uint256 _assetPrice = markets[_marketId].staticPrice;
                uint256 _borrowedMarketInUsd = _borrowedMarket * _assetPrice;
                _totalBorrowed += _borrowedMarketInUsd;
            }
        }
        // Calcular totalUsable restando el borrowed, pero sin underflow
        if (_totalBorrowed < _totalUsable) {
            _totalUsable -= _totalBorrowed;
        } else {
            _totalUsable = 0;
        }
    }

    function borrow(bytes32 _marketId, uint256 _amount) external whenNotPaused() nonReentrant() activeMarket(_marketId) {
        require(_amount > 0, "Amount can not be zero");
        Market storage _market = markets[_marketId];
        require(_market.totalBorrowed + _amount <= _market.totalSupply, "Total borrow exceed total supply");
        require(_market.totalBorrowed + _amount <= _market.borrowCap, "Borrow cap exceeded");
        
        uint256 _assetPrice = _market.staticPrice;
        uint256 _borrowInUsd = _amount * _assetPrice;
        uint256 _healthFactor = getHealthFactor(msg.sender, 0, _borrowInUsd);
        require(_healthFactor > 1, "Not enough collateral to borrow");
        

        UserData storage _user = usersData[msg.sender];
        _user.totalBorrowed[_marketId] += _amount;
        _user.lastUpdateTime = block.timestamp;
        _user.borrowMarkets.add(_marketId);

        _market.totalBorrowed += _amount;
        IERC20(_market.asset).safeTransfer(msg.sender, _amount);

        emit Borrow(_marketId, msg.sender, _amount);
    }

    function repay(bytes32 _marketId, uint256 _amount) external whenNotPaused() nonReentrant() activeMarket(_marketId) {
        require(_amount > 0, "Amount can not be zero");
        Market storage _market = markets[_marketId];
        UserData storage _user = usersData[msg.sender];

        require(_user.totalBorrowed[_marketId] >= _amount, "Not borrowed enough from this market");
        _user.totalBorrowed[_marketId] -= _amount;
        _user.lastUpdateTime = block.timestamp;
        if (_user.totalBorrowed[_marketId] == 0) {
            _user.borrowMarkets.remove(_marketId);
        }
        _market.totalBorrowed -= _amount;
        IERC20(_market.asset).safeTransferFrom(msg.sender, address(this), _amount);

        emit Repay(_marketId, msg.sender, _amount);
    }

    function getHealthFactor(address _userAddress, uint256 _newWithdrawAmount, uint256 _newBorrowAmount) public view returns (uint256 _healthFactor) {
        (uint256 _collateralInUsd,, uint256 _totalBorrowed) = getCollateralUsd(_userAddress);
        _totalBorrowed += _newBorrowAmount;

        if (_collateralInUsd > 0 && _totalBorrowed > 0) {
            _healthFactor = (_collateralInUsd - _newWithdrawAmount) * LIQUIDATION_THRESHOLD / BASIS_POINTS / (_totalBorrowed);
        } else if (_collateralInUsd > 0 && _totalBorrowed == 0){
            _healthFactor = type(uint256).max;
        } else {
            _healthFactor = 0;
        }
    }

    function liquidate(address _userAddress) external whenNotPaused() nonReentrant() {
        require(getHealthFactor(_userAddress, 0, 0) < 1, "The user position is not liquidable");
        UserData storage _user = usersData[_userAddress];

        for (uint256 i = 0; i < _user.collateralMarkets.length(); i++) {
            bytes32 _marketId = _user.collateralMarkets.at(i);
            uint256 _suppliedMarket = _user.totalSupplied[_marketId];
            if (_suppliedMarket > 0) {
                _user.totalSupplied[_marketId] = 0;
                IERC20(markets[_marketId].asset).safeTransfer(msg.sender, _suppliedMarket);
            }
        }
        _user.collateralMarkets.clear();

        for (uint256 i = 0; i < _user.borrowMarkets.length(); i++) {
            bytes32 _marketId = _user.borrowMarkets.at(i);
            uint256 _borrowedMarket = _user.totalBorrowed[_marketId];
            if (_borrowedMarket > 0) {
                _user.totalBorrowed[_marketId] = 0;
                IERC20(markets[_marketId].asset).safeTransferFrom(msg.sender, address(this), _borrowedMarket);
            }
        }
        _user.borrowMarkets.clear();
        _user.lastUpdateTime = block.timestamp;

        emit Liquidate(msg.sender, _userAddress);
    }

    function getUserDepositForMarket(address _user, bytes32 _marketId) external view returns (uint256 _amount) {
        _amount = usersData[_user].totalSupplied[_marketId];
    }

    function getUserBorrowForMarket(address _user, bytes32 _marketId) external view returns (uint256 _amount) {
        _amount = usersData[_user].totalBorrowed[_marketId];
    }


}