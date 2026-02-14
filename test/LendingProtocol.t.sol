// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test, stdStorage, StdStorage} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

import {LendingProtocol} from "../src/LendingProtocol.sol";
import {MockToken} from "../src/MockToken.sol";

contract TestLendingProtocol is Test {
    using stdStorage for StdStorage;
    LendingProtocol protocol;
    MockToken wEth;
    MockToken usdc;
    MockToken usdt;

    address deployer = vm.addr(1);
    address lender1 = vm.addr(2);
    address lender2 = vm.addr(3);
    address lender3 = vm.addr(4);
    address borrower1 = vm.addr(5);
    address borrower2 = vm.addr(6);
    address borrower3 = vm.addr(7);

    function setUp() external {
        vm.startPrank(deployer);
        protocol = new LendingProtocol();
        wEth = new MockToken("Wrapped Ether", "WETH");
        usdc = new MockToken("USD Coin", "USDC");
        usdt = new MockToken("USD Tether", "USDT");
        vm.stopPrank();
    }

    function mintToUsers1() public {
        vm.startPrank(deployer);
        wEth.mint(lender1, 5000 * 1e18);
        wEth.mint(borrower1, 5000 * 1e18);
        vm.stopPrank();
    }

    function mintToUsers2() public {
        vm.startPrank(deployer);
        usdc.mint(lender2, 10000 * 1e18);
        usdc.mint(borrower2, 10000 * 1e18);
        vm.stopPrank();
    }

    function mintToUsers3() public {
        vm.startPrank(deployer);
        usdt.mint(lender3, 10000 * 1e18);
        usdt.mint(borrower3, 10000 * 1e18);
        vm.stopPrank();
    }

    function createWEtherMarket() public {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 2000 * 1e18;
        uint256 _borrowCap = 500 * 1e18;
        uint256 _ltv = 5000;
        uint256 _staticPrice = 2000;
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function createUsdcMarket() public {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(usdc);
        uint256 _supplyCap = 20000 * 1e18;
        uint256 _borrowCap = 5000 * 1e18;
        uint256 _ltv = 6000;
        uint256 _staticPrice = 1;
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function getWEtherMarketId() public view returns(bytes32 _marketId) {
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        _marketId = protocol.encodeMarketIdentifier(_marketName, _asset);
    }

    function getUsdcMarketId() public view returns(bytes32 _marketId) {
        string memory _marketName = "Test Market";
        address _asset = address(usdc);
        _marketId = protocol.encodeMarketIdentifier(_marketName, _asset);
    }

    function testRevertPause_NotOwner() external {
        vm.startPrank(lender1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, lender1));
        protocol.pause();
        vm.stopPrank();
    }

    function testPause() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());
        vm.stopPrank();
    }

    function testRevertUnpause_NotOwner() external {
        vm.startPrank(lender1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, lender1));
        protocol.unpause();
        vm.stopPrank();
    }

    function testUnpause() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());
        protocol.unpause();
        assert(!protocol.paused());
        vm.stopPrank();
    }

    function testRevertCreateMarket_NotOwner() external {
        vm.startPrank(lender1);
        string memory _marketName = "";
        address _asset = address(0);
        uint256 _supplyCap = 0;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, lender1));
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_IsPaused() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());
        string memory _marketName = "";
        address _asset = address(0);
        uint256 _supplyCap = 0;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_AlreadyExists() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 5000 * 1e18;
        uint256 _borrowCap = 5000 * 1e18;
        uint256 _ltv = 500;
        uint256 _staticPrice = 2000;
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.expectRevert("Market already exists");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_MarketNameEmpty() external {
        vm.startPrank(deployer);
        string memory _marketName = "";
        address _asset = address(0);
        uint256 _supplyCap = 0;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert("Market name can not be empty");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_InvalidAsset() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(0);
        uint256 _supplyCap = 0;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert("Invalid asset");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_SuppyCapZero() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 0;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert("Supply cap can not be zero");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_BorrowCapZero() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 5000 * 1e18;
        uint256 _borrowCap = 0;
        uint256 _ltv = 0;
        uint256 _staticPrice = 0;
        vm.expectRevert("Borrow cap can not be zero");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_LTVGreaterBasisPoints() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 5000 * 1e18;
        uint256 _borrowCap = 5000 * 1e18;
        uint256 _ltv = 10001;
        uint256 _staticPrice = 0;
        vm.expectRevert("LTV can not be greater than BASIS_POINTS");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertCreateMarket_StaticPriceZero() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 5000 * 1e18;
        uint256 _borrowCap = 5000 * 1e18;
        uint256 _ltv = 500;
        uint256 _staticPrice = 0;
        vm.expectRevert("Static price can not be zero");
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testCreateMarket() external {
        vm.startPrank(deployer);
        string memory _marketName = "Test Market";
        address _asset = address(wEth);
        uint256 _supplyCap = 5000 * 1e18;
        uint256 _borrowCap = 5000 * 1e18;
        uint256 _ltv = 500;
        uint256 _staticPrice = 2000;
        protocol.createMarket(_marketName, _asset, _supplyCap, _borrowCap, _ltv, _staticPrice);
        vm.stopPrank();
    }

    function testRevertLend_IsPaused() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 0;
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        protocol.lend(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertLend_NotExistsOrInactiveMarket() external {
        vm.startPrank(deployer);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 0;
        vm.expectRevert("Market not active or not exists");
        protocol.lend(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertLend_AmountZero() external {
        createWEtherMarket();
        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 0;
        vm.expectRevert("Amount can not be zero");
        protocol.lend(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertLend_SupplyCapExceed() external {
        createWEtherMarket();
        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 2001 * 1e18;
        vm.expectRevert("Supply cap exceeded");
        protocol.lend(_marketId, _amount);
        vm.stopPrank();
    }

    function testLend() external {
        mintToUsers1();
        createWEtherMarket();

        uint256 _lenderBalanceBefore = IERC20(address(wEth)).balanceOf(lender1);
        uint256 _protocolBalanceBefore = IERC20(address(wEth)).balanceOf(address(protocol));

        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 1000 * 1e18;
        wEth.approve(address(protocol), _amount);
        protocol.lend(_marketId, _amount);

        (, uint256 _marketSupply,,,,,,) = protocol.markets(_marketId);
        uint256 _userSupply = protocol.getUserDepositForMarket(lender1, _marketId);

        assert(_marketSupply == _amount);
        assert(_userSupply == _amount);

        uint256 _lenderBalanceAfter = IERC20(address(wEth)).balanceOf(lender1);
        uint256 _protocolBalanceAfter = IERC20(address(wEth)).balanceOf(address(protocol));

        assert(_lenderBalanceBefore - _amount == _lenderBalanceAfter);
        assert(_protocolBalanceBefore + _amount == _protocolBalanceAfter);
        vm.stopPrank();
    }

    function testRevertWithdraw_IsPaused() external {
        vm.startPrank(deployer);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 1000 * 1e18;

        protocol.pause();
        assert(protocol.paused());

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        protocol.withdraw(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertWithdraw_NotExistsOrInactiveMarket() external {
        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 1000 * 1e18;

        vm.expectRevert("Market not active or not exists");
        protocol.withdraw(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertWithdraw_AmountZero() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;
        uint256 _amountToWithdraw = 0;

        protocol.lend(_marketId, _amountToLend);
        vm.expectRevert("Amount can not be zero");
        protocol.withdraw(_marketId, _amountToWithdraw);

        vm.stopPrank();
    }

    function testRevertWithdraw_NotEnoughSupplied() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;
        uint256 _amountToWithdraw = 1001 * 1e18;

        protocol.lend(_marketId, _amountToLend);
        vm.expectRevert("Not enough supplied in this market");
        protocol.withdraw(_marketId, _amountToWithdraw);
        
        vm.stopPrank();
    }

    function testRevertWithdraw_NotEnoughCollateral() external {
        mintToUsers1();
        createWEtherMarket();
        createUsdcMarket();

        bytes32 _marketId = getWEtherMarketId();

        vm.startPrank(borrower1);
        wEth.approve(address(protocol), 1 * 1e18);
        uint256 _amountToLend = 1 * 1e18;
        uint256 _amountToWithdraw = 6 * 1e17;
        uint256 _amountToBorrow = 4 * 1e17;

        protocol.lend(_marketId, _amountToLend);
        protocol.borrow(_marketId, _amountToBorrow);

        vm.expectRevert("Not enough collateral to withdraw");
        protocol.withdraw(_marketId, _amountToWithdraw);
        vm.stopPrank();
    }

    function testWithdraw() external {
        mintToUsers1();
        createWEtherMarket();

        uint256 _lenderBalanceBefore = IERC20(address(wEth)).balanceOf(lender1);
        uint256 _protocolBalanceBefore = IERC20(address(wEth)).balanceOf(address(protocol));

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;
        uint256 _amountToWithdraw = 500 * 1e18;

        protocol.lend(_marketId, _amountToLend);

        (, uint256 _marketSupply,,,,,,) = protocol.markets(_marketId);
        uint256 _userSupply = protocol.getUserDepositForMarket(lender1, _marketId);

        protocol.withdraw(_marketId, _amountToWithdraw);

        uint256 _lenderBalanceAfter = IERC20(address(wEth)).balanceOf(lender1);
        uint256 _protocolBalanceAfter = IERC20(address(wEth)).balanceOf(address(protocol));

        (, uint256 _marketSupplyAfter,,,,,,) = protocol.markets(_marketId);
        uint256 _userSupplyAfter = protocol.getUserDepositForMarket(lender1, _marketId);

        assert(_lenderBalanceBefore - _amountToLend + _amountToWithdraw == _lenderBalanceAfter);
        assert(_protocolBalanceBefore + _amountToLend - _amountToWithdraw == _protocolBalanceAfter);

        assert(_marketSupply - _amountToWithdraw == _marketSupplyAfter);
        assert(_userSupply - _amountToWithdraw == _userSupplyAfter);

        protocol.withdraw(_marketId, _amountToWithdraw);

        assert(protocol.getUserDepositForMarket(lender1, _marketId) == 0);
        
        vm.stopPrank();
    }

    function testRevertBorrow_IsPaused() external {
        vm.startPrank(deployer);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 1000 * 1e18;

        protocol.pause();
        assert(protocol.paused());

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        protocol.borrow(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertBorrow_NotExistsOrInactiveMarket() external {
        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amount = 1000 * 1e18;

        vm.expectRevert("Market not active or not exists");
        protocol.borrow(_marketId, _amount);
        vm.stopPrank();
    }

    function testRevertBorrow_AmountZero() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToBorrow = 0;

        vm.expectRevert("Amount can not be zero");
        protocol.borrow(_marketId, _amountToBorrow);

        vm.stopPrank();
    }

    function testRevertBorrow_BorrowExceedSupply() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToBorrow = 500 * 1e18;

        (, uint256 _marketSupply,,,,,,) = protocol.markets(_marketId);
        console.log(_marketSupply);

        vm.expectRevert("Total borrow exceed total supply");
        protocol.borrow(_marketId, _amountToBorrow);
        
        vm.stopPrank();
    }

    function testRevertBorrow_BorrowCapExceed() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;
        uint256 _amountToBorrow = 501 * 1e18;

        protocol.lend(_marketId, _amountToLend);
        vm.expectRevert("Borrow cap exceeded");
        protocol.borrow(_marketId, _amountToBorrow);
        
        vm.stopPrank();
    }

    function testRevertBorrow_NotEnoughCollateral() external {
        mintToUsers1();
        createWEtherMarket();

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;

        protocol.lend(_marketId, _amountToLend);
        vm.stopPrank();

        vm.startPrank(borrower1);
        uint256 _amountToBorrow = 1 * 1e18;
        vm.expectRevert("Not enough collateral to borrow");
        protocol.borrow(_marketId, _amountToBorrow);
        
        vm.stopPrank();
    }

    function testBorrow() external {
        mintToUsers1();
        createWEtherMarket();

        uint256 _balanceBefore = wEth.balanceOf(lender1);

        vm.startPrank(lender1);
        wEth.approve(address(protocol), 5000 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 1000 * 1e18;

        protocol.lend(_marketId, _amountToLend);
        uint256 _amountToBorrow = 1 * 1e18;

        protocol.borrow(_marketId, _amountToBorrow);
        vm.stopPrank();

        uint256 _balanceAfter = wEth.balanceOf(lender1);
        assert(_balanceBefore - _amountToLend + _amountToBorrow == _balanceAfter);

    }

    function testRevertRepay_IsPaused() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());

        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToRepay = 1000 * 1e18;
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        protocol.repay(_marketId, _amountToRepay);

        vm.stopPrank();
    }

    function testRevertRepay_NotExistsOrInactiveMarket() external {
        vm.startPrank(borrower1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToRepay = 1000 * 1e18;
        vm.expectRevert("Market not active or not exists");
        protocol.repay(_marketId, _amountToRepay);
        vm.stopPrank();
    }

    function testRevertRepay_AmountZero() external {
        createWEtherMarket();
        vm.startPrank(borrower1);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToRepay = 0;
        vm.expectRevert("Amount can not be zero");
        protocol.repay(_marketId, _amountToRepay);
        vm.stopPrank();
    }

    function testRevertRepay_NotBorrowedEnough() external {
        mintToUsers1();
        createWEtherMarket();
        vm.startPrank(borrower1);
        wEth.approve(address(protocol), 200 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 100 * 1e18;
        protocol.lend(_marketId, _amountToLend);
        uint256 _amountToBorrow = 25 * 1e18;
        protocol.borrow(_marketId, _amountToBorrow);
        uint256 _amountToRepay = 26 * 1e18;
        vm.expectRevert("Not borrowed enough from this market");
        protocol.repay(_marketId, _amountToRepay);
        vm.stopPrank();
    }

    function testRepay() external {
        mintToUsers1();
        createWEtherMarket();
        vm.startPrank(borrower1);
        wEth.approve(address(protocol), 200 * 1e18);
        bytes32 _marketId = getWEtherMarketId();
        uint256 _amountToLend = 100 * 1e18;
        protocol.lend(_marketId, _amountToLend);
        uint256 _amountToBorrow = 25 * 1e18;
        protocol.borrow(_marketId, _amountToBorrow);
        uint256 _amountToRepay = 25 * 1e18;
        protocol.repay(_marketId, _amountToRepay);
        vm.stopPrank();
    }

    function testRevertLiquidate_IsPaused() external {
        vm.startPrank(deployer);
        protocol.pause();
        assert(protocol.paused());

        address _userToLiquidate = borrower2;
        vm.expectRevert();
        protocol.liquidate(_userToLiquidate);
        vm.stopPrank();
    }

    function testRevertLiquidate_UserNotLiquidable() external {
        mintToUsers1();
        mintToUsers2();
        createWEtherMarket();
        createUsdcMarket();
        bytes32 _wEthMarketId = getWEtherMarketId();
        bytes32 _usdcMarketId = getUsdcMarketId();

        vm.startPrank(lender2);
        usdc.approve(address(protocol), 5000 * 1e18);
        protocol.lend(_usdcMarketId, 5000 * 1e18);
        vm.stopPrank();

        vm.startPrank(borrower1);

        uint256 _amountToLend = 2 * 1e18;
        uint256 _amountToBorrow = 1000 * 1e18;
        wEth.approve(address(protocol), _amountToLend);

        protocol.lend(_wEthMarketId, _amountToLend);
        protocol.borrow(_usdcMarketId, _amountToBorrow);
        vm.stopPrank();
        vm.startPrank(lender2);

        address _userToLiquidate = borrower1;
        vm.expectRevert("The user position is not liquidable");
        protocol.liquidate(_userToLiquidate);
        vm.stopPrank();
    }

    function testLiquidate() external {
        createWEtherMarket();
        createUsdcMarket();
        mintToUsers1();
        mintToUsers2();
        bytes32 _wEthMarketId = getWEtherMarketId();
        bytes32 _usdcMarketId = getUsdcMarketId();

        uint256 _liquidatorWEtherBalanceBefore = wEth.balanceOf(borrower2);
        uint256 _liquidatorUsdcBalanceBefore = usdc.balanceOf(borrower2);

        vm.startPrank(lender2);
        usdc.approve(address(protocol), 5000 * 1e18);
        protocol.lend(_usdcMarketId, 5000 * 1e18);
        vm.stopPrank();

        vm.startPrank(borrower1);
        wEth.approve(address(protocol), 1 * 1e18);
        uint256 _amountToLend = 1 * 1e18;
        uint256 _amountToBorrow = 800 * 1e18;

        protocol.lend(_wEthMarketId, _amountToLend);
        protocol.borrow(_usdcMarketId, _amountToBorrow);
        vm.stopPrank();

        assert(protocol.getUserDepositForMarket(borrower1, _wEthMarketId) == _amountToLend);
        assert(protocol.getUserBorrowForMarket(borrower1, _usdcMarketId) == _amountToBorrow);

        // Modify storage to decrease wEther price to force liquidation
        stdstore.target(address(protocol)).sig("markets(bytes32)").with_key(_wEthMarketId).depth(7).checked_write(950);

        vm.startPrank(borrower2);
        usdc.approve(address(protocol), 5000 * 1e18);

        address _userToLiquidate = borrower1;
        protocol.liquidate(_userToLiquidate);
        vm.stopPrank();

        uint256 _liquidatorWEtherBalanceAfter = wEth.balanceOf(borrower2);
        uint256 _liquidatorUsdcBalanceAfter = usdc.balanceOf(borrower2);

        assert(_liquidatorWEtherBalanceBefore + _amountToLend == _liquidatorWEtherBalanceAfter);
        assert(_liquidatorUsdcBalanceBefore - _amountToBorrow == _liquidatorUsdcBalanceAfter);

        assert(protocol.getUserDepositForMarket(borrower1, _wEthMarketId) == 0);
        assert(protocol.getUserDepositForMarket(borrower1, _usdcMarketId) == 0);
    }
    
    function testGetCollateralAndFactor() external view {
        protocol.getCollateralUsd(lender1);
        protocol.getHealthFactor(lender1, 0,0);
    }





}