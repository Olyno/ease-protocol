pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/ComptrollerHarness.sol";

contract LiquidateTest is Test {
    ComptrollerHarness comptroller;
    CErc20Harness cToken;
    CErc20Harness cTokenCollateral;
    address root;
    address liquidator;
    address borrower;
    address[] accounts;

    uint256 repayAmount = 10e18;
    uint256 seizeTokens = repayAmount * 4;
    uint256 protocolSeizeShareMantissa = 2.8e16;
    uint256 exchangeRate = 0.2e18;
    uint256 protocolShareTokens = seizeTokens * protocolSeizeShareMantissa / 1e18;
    uint256 liquidatorShareTokens = seizeTokens - protocolShareTokens;
    uint256 addReservesAmount = protocolShareTokens * exchangeRate / 1e18;

    function setUp() public {
        root = address(this);
        liquidator = address(0x1);
        borrower = address(0x2);
        accounts = new address[](10);
        for (uint256 i = 0; i < accounts.length; i++) {
            accounts[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        cToken = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(0)),
            1e18,
            "cToken",
            "cToken",
            18,
            payable(address(this))
        );
        cTokenCollateral = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(0)),
            1e18,
            "cTokenCollateral",
            "cTokenCollateral",
            18,
            payable(address(this))
        );

        setUpLiquidation();
    }

    function setUpLiquidation() internal {
        comptroller.setLiquidateBorrowAllowed(true);
        comptroller.setLiquidateBorrowVerify(true);
        comptroller.setRepayBorrowAllowed(true);
        comptroller.setRepayBorrowVerify(true);
        comptroller.setSeizeAllowed(true);
        comptroller.setSeizeVerify(true);
        comptroller.setFailCalculateSeizeTokens(false);
        cToken.underlying().harnessSetFailTransferFromAddress(liquidator, false);
        cToken.interestRateModel().setFailBorrowRate(false);
        cTokenCollateral.interestRateModel().setFailBorrowRate(false);
        comptroller.setCalculatedSeizeTokens(seizeTokens);
        cTokenCollateral.harnessSetTotalSupply(10e18);
        cTokenCollateral.harnessSetBalance(liquidator, 0);
        cTokenCollateral.harnessSetBalance(borrower, seizeTokens);
        cTokenCollateral.harnessSetAccountBorrows(borrower, 0, 1);
        cToken.harnessSetAccountBorrows(borrower, 1, 1);
        cToken.harnessSetTotalBorrows(repayAmount);
        cToken.harnessSetBalance(borrower, repayAmount);
        cToken.harnessSetBalance(liquidator, 0);
        cToken.harnessSetTotalSupply(10e18);
        cToken.harnessSetExchangeRate(exchangeRate);
    }

    function testLiquidateBorrowFresh() public {
        uint256 beforeLiquidatorBalance = cToken.balanceOf(liquidator);
        uint256 beforeBorrowerBalance = cToken.balanceOf(borrower);
        uint256 beforeTotalBorrows = cToken.totalBorrows();
        uint256 beforeTotalReserves = cToken.totalReserves();

        cToken.liquidateBorrowFresh(liquidator, borrower, repayAmount, cTokenCollateral);

        uint256 afterLiquidatorBalance = cToken.balanceOf(liquidator);
        uint256 afterBorrowerBalance = cToken.balanceOf(borrower);
        uint256 afterTotalBorrows = cToken.totalBorrows();
        uint256 afterTotalReserves = cToken.totalReserves();

        assertEq(afterLiquidatorBalance, beforeLiquidatorBalance + liquidatorShareTokens);
        assertEq(afterBorrowerBalance, beforeBorrowerBalance - seizeTokens);
        assertEq(afterTotalBorrows, beforeTotalBorrows - repayAmount);
        assertEq(afterTotalReserves, beforeTotalReserves + addReservesAmount);
    }

    function testLiquidateBorrow() public {
        uint256 beforeLiquidatorBalance = cToken.balanceOf(liquidator);
        uint256 beforeBorrowerBalance = cToken.balanceOf(borrower);
        uint256 beforeTotalBorrows = cToken.totalBorrows();
        uint256 beforeTotalReserves = cToken.totalReserves();

        cToken.liquidateBorrow(borrower, repayAmount, cTokenCollateral);

        uint256 afterLiquidatorBalance = cToken.balanceOf(liquidator);
        uint256 afterBorrowerBalance = cToken.balanceOf(borrower);
        uint256 afterTotalBorrows = cToken.totalBorrows();
        uint256 afterTotalReserves = cToken.totalReserves();

        assertEq(afterLiquidatorBalance, beforeLiquidatorBalance + liquidatorShareTokens);
        assertEq(afterBorrowerBalance, beforeBorrowerBalance - seizeTokens);
        assertEq(afterTotalBorrows, beforeTotalBorrows - repayAmount);
        assertEq(afterTotalReserves, beforeTotalReserves + addReservesAmount);
    }

    function testSeize() public {
        uint256 beforeLiquidatorBalance = cTokenCollateral.balanceOf(liquidator);
        uint256 beforeBorrowerBalance = cTokenCollateral.balanceOf(borrower);
        uint256 beforeTotalReserves = cTokenCollateral.totalReserves();

        cTokenCollateral.seize(liquidator, borrower, seizeTokens);

        uint256 afterLiquidatorBalance = cTokenCollateral.balanceOf(liquidator);
        uint256 afterBorrowerBalance = cTokenCollateral.balanceOf(borrower);
        uint256 afterTotalReserves = cTokenCollateral.totalReserves();

        assertEq(afterLiquidatorBalance, beforeLiquidatorBalance + liquidatorShareTokens);
        assertEq(afterBorrowerBalance, beforeBorrowerBalance - seizeTokens);
        assertEq(afterTotalReserves, beforeTotalReserves + addReservesAmount);
    }
}
