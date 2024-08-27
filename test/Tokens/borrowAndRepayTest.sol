pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";
import "../../src/InterestRateModel.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";

contract BorrowAndRepayTest is Test {
    CErc20Harness cToken;
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    address root;
    address borrower;
    address benefactor;
    address[] accounts;

    uint256 borrowAmount = 10e3;
    uint256 repayAmount = 10e2;

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

        borrower = accounts[1];
        benefactor = accounts[2];
    }

    function preBorrow() internal {
        comptroller.setBorrowAllowed(true);
        comptroller.setBorrowVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetFailTransferToAddress(borrower, false);
        cToken.harnessSetAccountBorrows(borrower, 0, 0);
        cToken.harnessSetTotalBorrows(0);
        cToken.underlying().harnessSetBalance(address(cToken), borrowAmount);
    }

    function borrowFresh() internal returns (uint256) {
        return cToken.harnessBorrowFresh(borrower, borrowAmount);
    }

    function borrow() internal returns (uint256) {
        cToken.harnessFastForward(1);
        return cToken.borrow(borrowAmount);
    }

    function preRepay() internal {
        comptroller.setRepayBorrowAllowed(true);
        comptroller.setRepayBorrowVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetAccountBorrows(borrower, 1, 1);
        cToken.harnessSetTotalBorrows(repayAmount);
    }

    function repayBorrowFresh() internal returns (uint256) {
        return cToken.harnessRepayBorrowFresh(borrower, borrower, repayAmount);
    }

    function repayBorrow() internal returns (uint256) {
        cToken.harnessFastForward(1);
        return cToken.repayBorrow(repayAmount);
    }

    function repayBorrowBehalf() internal returns (uint256) {
        cToken.harnessFastForward(1);
        return cToken.repayBorrowBehalf(borrower, repayAmount);
    }

    function testBorrowFresh() public {
        preBorrow();

        // Test cases for borrowFresh
        assertEq(comptroller.borrowAllowed(), true);
        assertEq(comptroller.borrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessFailTransferToAddress(borrower), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 0));
        assertEq(cToken.harnessTotalBorrows(), 0);
        assertEq(cToken.underlying().balanceOf(address(cToken)), borrowAmount);

        // Test borrowFresh
        assertEq(borrowFresh(), 0);
    }

    function testBorrow() public {
        preBorrow();

        // Test cases for borrow
        assertEq(comptroller.borrowAllowed(), true);
        assertEq(comptroller.borrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessFailTransferToAddress(borrower), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 0));
        assertEq(cToken.harnessTotalBorrows(), 0);
        assertEq(cToken.underlying().balanceOf(address(cToken)), borrowAmount);

        // Test borrow
        assertEq(borrow(), 0);
    }

    function testRepayBorrowFresh() public {
        preRepay();

        // Test cases for repayBorrowFresh
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (1, 1));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrowFresh
        assertEq(repayBorrowFresh(), 0);
    }

    function testRepayBorrow() public {
        preRepay();

        // Test cases for repayBorrow
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (1, 1));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrow
        assertEq(repayBorrow(), 0);
    }

    function testRepayBorrowBehalf() public {
        preRepay();

        // Test cases for repayBorrowBehalf
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (1, 1));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrowBehalf
        assertEq(repayBorrowBehalf(), 0);
    }
}
