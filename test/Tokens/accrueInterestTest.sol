pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";
import "../../src/InterestRateModel.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";

contract AccrueInterestTest is Test {
    CErc20Harness cToken;
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    address root;
    address[] accounts;

    uint256 blockNumber = 2e7;
    uint256 borrowIndex = 1e18;
    uint256 borrowRate = .000001;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint256 i = 0; i < accounts.length; i++) {
            accounts[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        interestRateModel = new InterestRateModelHarness();
        cToken = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(interestRateModel)),
            1e18,
            "cToken",
            "cToken",
            18,
            payable(address(this))
        );

        preAccrue();
    }

    function pretendBlock(uint256 accrualBlock, uint256 deltaBlocks) internal {
        cToken.harnessSetAccrualBlockNumber(accrualBlock);
        cToken.harnessSetBlockNumber(accrualBlock + deltaBlocks);
        cToken.harnessSetBorrowIndex(borrowIndex);
    }

    function preAccrue() internal {
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetBorrowRate(borrowRate);
        cToken.harnessExchangeRateDetails(0, 0, 0);
    }

    function testAccrueInterestRevertsIfInterestRateIsHigh() public {
        pretendBlock(blockNumber, 1);
        assertEq(cToken.getBorrowRateMaxMantissa(), 0.000005e18);
        cToken.harnessSetBorrowRate(0.001e-2);
        vm.expectRevert("borrow rate is absurdly high");
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfNewBorrowRateFails() public {
        pretendBlock(blockNumber, 1);
        interestRateModel.setFailBorrowRate(true);
        vm.expectRevert("INTEREST_RATE_MODEL_ERROR");
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfSimpleInterestFactorFails() public {
        pretendBlock(blockNumber, 5e70);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfNewBorrowIndexFails() public {
        pretendBlock(blockNumber, 5e60);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfNewBorrowInterestIndexFails() public {
        pretendBlock(blockNumber, 1);
        cToken.harnessSetBorrowIndex(type(uint256).max);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfInterestAccumulatedFails() public {
        cToken.harnessExchangeRateDetails(0, type(uint256).max, 0);
        pretendBlock(blockNumber, 1);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfNewTotalBorrowsFails() public {
        cToken.harnessSetBorrowRate(1e-18);
        cToken.harnessExchangeRateDetails(0, type(uint256).max, 0);
        pretendBlock(blockNumber, 1);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfInterestAccumulatedForReservesFails() public {
        cToken.harnessSetBorrowRate(.000001);
        cToken.harnessExchangeRateDetails(0, 1e30, type(uint256).max);
        cToken.harnessSetReserveFactorFresh(1e10);
        pretendBlock(blockNumber, 5e20);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestFailsIfNewTotalReservesFails() public {
        cToken.harnessSetBorrowRate(1e-18);
        cToken.harnessExchangeRateDetails(0, 1e56, type(uint256).max);
        cToken.harnessSetReserveFactorFresh(1e17);
        pretendBlock(blockNumber, 1);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterestSucceeds() public {
        uint256 startingTotalBorrows = 1e22;
        uint256 startingTotalReserves = 1e20;
        uint256 reserveFactor = 1e17;

        cToken.harnessExchangeRateDetails(0, startingTotalBorrows, startingTotalReserves);
        cToken.harnessSetReserveFactorFresh(reserveFactor);
        pretendBlock(blockNumber, 1);

        uint256 expectedAccrualBlockNumber = blockNumber + 1;
        uint256 expectedBorrowIndex = borrowIndex + borrowIndex * borrowRate;
        uint256 expectedTotalBorrows = startingTotalBorrows + startingTotalBorrows * borrowRate;
        uint256 expectedTotalReserves = startingTotalReserves + startingTotalBorrows * borrowRate * reserveFactor / 1e18;

        cToken.accrueInterest();

        assertEq(cToken.accrualBlockNumber(), expectedAccrualBlockNumber);
        assertEq(cToken.borrowIndex(), expectedBorrowIndex);
        assertEq(cToken.totalBorrows(), expectedTotalBorrows);
        assertEq(cToken.totalReserves(), expectedTotalReserves);
    }
}
