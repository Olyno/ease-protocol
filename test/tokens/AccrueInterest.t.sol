pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/InterestRateModel.sol";
import "../Utils/Compound.sol";

contract AccrueInterestTest is Test {
    CToken cToken;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
    address root;
    address[] accounts;

    uint256 blockNumber = 2e7;
    uint256 borrowIndex = 1e18;
    uint256 borrowRate = 0.000001e18;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
        comptroller = new Comptroller();
        interestRateModel = new InterestRateModel();
        cToken = new CToken(address(comptroller), address(interestRateModel), 1e18, "CToken", "CTK", 18);
    }

    function pretendBlock(uint256 accrualBlock, uint256 deltaBlocks) internal {
        cToken.harnessSetAccrualBlockNumber(accrualBlock);
        cToken.harnessSetBlockNumber(accrualBlock + deltaBlocks);
        cToken.harnessSetBorrowIndex(borrowIndex);
    }

    function preAccrue() internal {
        cToken.harnessSetBorrowRate(borrowRate);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessExchangeRateDetails(0, 0, 0);
    }

    function testAccrueInterest_BorrowRateAbsurdlyHigh() public {
        preAccrue();
        pretendBlock(blockNumber, 1);
        assertEq(cToken.getBorrowRateMaxMantissa(), 0.000005e18); // 0.0005% per block
        cToken.harnessSetBorrowRate(0.001e18); // 0.0010% per block
        vm.expectRevert("borrow rate is absurdly high");
        cToken.accrueInterest();
    }

    function testAccrueInterest_NewBorrowRateCalculationFails() public {
        preAccrue();
        pretendBlock(blockNumber, 1);
        interestRateModel.setFailBorrowRate(true);
        vm.expectRevert("INTEREST_RATE_MODEL_ERROR");
        cToken.accrueInterest();
    }

    function testAccrueInterest_SimpleInterestFactorCalculationFails() public {
        preAccrue();
        pretendBlock(blockNumber, 5e70);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_NewBorrowIndexCalculationFails() public {
        preAccrue();
        pretendBlock(blockNumber, 5e60);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_NewBorrowInterestIndexCalculationFails() public {
        preAccrue();
        pretendBlock(blockNumber, 1);
        cToken.harnessSetBorrowIndex(UInt256Max());
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_InterestAccumulatedCalculationFails() public {
        preAccrue();
        cToken.harnessExchangeRateDetails(0, UInt256Max(), 0);
        pretendBlock(blockNumber, 1);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_NewTotalBorrowsCalculationFails() public {
        preAccrue();
        cToken.harnessSetBorrowRate(1e-18);
        pretendBlock(blockNumber, 1);
        cToken.harnessExchangeRateDetails(0, UInt256Max(), 0);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_InterestAccumulatedForReservesCalculationFails() public {
        preAccrue();
        cToken.harnessSetBorrowRate(0.000001e18);
        cToken.harnessExchangeRateDetails(0, 1e30, UInt256Max());
        cToken.harnessSetReserveFactorFresh(1e10);
        pretendBlock(blockNumber, 5e20);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_NewTotalReservesCalculationFails() public {
        preAccrue();
        cToken.harnessSetBorrowRate(1e-18);
        cToken.harnessExchangeRateDetails(0, 1e56, UInt256Max());
        cToken.harnessSetReserveFactorFresh(1e17);
        pretendBlock(blockNumber, 1);
        vm.expectRevert();
        cToken.accrueInterest();
    }

    function testAccrueInterest_Success() public {
        preAccrue();
        uint256 startingTotalBorrows = 1e22;
        uint256 startingTotalReserves = 1e20;
        uint256 reserveFactor = 1e17;

        cToken.harnessExchangeRateDetails(0, startingTotalBorrows, startingTotalReserves);
        cToken.harnessSetReserveFactorFresh(reserveFactor);
        pretendBlock(blockNumber, 1);

        uint256 expectedAccrualBlockNumber = blockNumber + 1;
        uint256 expectedBorrowIndex = borrowIndex + (borrowIndex * borrowRate);
        uint256 expectedTotalBorrows = startingTotalBorrows + (startingTotalBorrows * borrowRate);
        uint256 expectedTotalReserves = startingTotalReserves + (startingTotalBorrows * borrowRate * reserveFactor / 1e18);

        cToken.accrueInterest();

        assertEq(cToken.accrualBlockNumber(), expectedAccrualBlockNumber);
        assertEq(cToken.borrowIndex(), expectedBorrowIndex);
        assertEq(cToken.totalBorrows(), expectedTotalBorrows);
        assertEq(cToken.totalReserves(), expectedTotalReserves);
    }
}
