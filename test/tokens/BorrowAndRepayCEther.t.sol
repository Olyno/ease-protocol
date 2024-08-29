pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CEther.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/InterestRateModel.sol";
import "../Utils/Compound.sol";

contract BorrowAndRepayCEtherTest is Test {
    CEther cToken;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
    address root;
    address borrower;
    address benefactor;
    address[] accounts;

    uint256 borrowAmount = 10e3;
    uint256 repayAmount = 10e2;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
        borrower = accounts[1];
        benefactor = accounts[2];
        comptroller = new Comptroller();
        interestRateModel = new InterestRateModel();
        cToken = new CEther(comptroller, interestRateModel, 1e18, "CEther", "cETH", 8, root);
    }

    function preBorrow() internal {
        comptroller.setBorrowAllowed(true);
        comptroller.setBorrowVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetFailTransferToAddress(borrower, false);
        cToken.harnessSetAccountBorrows(borrower, 0, 0);
        cToken.harnessSetTotalBorrows(0);
        cToken.harnessSetEtherBalance(borrowAmount);
    }

    function borrowFresh() internal returns (uint) {
        return cToken.harnessBorrowFresh(borrower, borrowAmount);
    }

    function borrow() internal returns (uint) {
        cToken.harnessFastForward(1);
        return cToken.borrow(borrowAmount);
    }

    function preRepay() internal {
        comptroller.setRepayBorrowAllowed(true);
        comptroller.setRepayBorrowVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.pretendBorrow(borrower, 1, 1, repayAmount);
    }

    function repayBorrowFresh() internal returns (uint) {
        return cToken.harnessRepayBorrowFresh(benefactor, borrower, repayAmount);
    }

    function repayBorrow() internal returns (uint) {
        cToken.harnessFastForward(1);
        return cToken.repayBorrow(repayAmount);
    }

    function repayBorrowBehalf() internal returns (uint) {
        cToken.harnessFastForward(1);
        return cToken.repayBorrowBehalf(borrower, repayAmount);
    }

    function testBorrowFresh() public {
        preBorrow();

        // Test cases
        assertEq(comptroller.borrowAllowed(), true);
        assertEq(comptroller.borrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessFailTransferToAddress(borrower), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 0));
        assertEq(cToken.harnessTotalBorrows(), 0);
        assertEq(cToken.harnessEtherBalance(), borrowAmount);

        // Test borrowFresh
        assertEq(borrowFresh(), 0);
        assertEq(cToken.harnessAccountBorrows(borrower), (borrowAmount, 1e18));
        assertEq(cToken.harnessTotalBorrows(), borrowAmount);
        assertEq(cToken.harnessEtherBalance(), 0);
    }

    function testBorrow() public {
        preBorrow();

        // Test cases
        assertEq(comptroller.borrowAllowed(), true);
        assertEq(comptroller.borrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessFailTransferToAddress(borrower), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 0));
        assertEq(cToken.harnessTotalBorrows(), 0);
        assertEq(cToken.harnessEtherBalance(), borrowAmount);

        // Test borrow
        assertEq(borrow(), 0);
        assertEq(cToken.harnessAccountBorrows(borrower), (borrowAmount, 1e18));
        assertEq(cToken.harnessTotalBorrows(), borrowAmount);
        assertEq(cToken.harnessEtherBalance(), 0);
    }

    function testRepayBorrowFresh() public {
        preRepay();

        // Test cases
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (repayAmount, 1e18));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrowFresh
        assertEq(repayBorrowFresh(), 0);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 1e18));
        assertEq(cToken.harnessTotalBorrows(), 0);
    }

    function testRepayBorrow() public {
        preRepay();

        // Test cases
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (repayAmount, 1e18));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrow
        assertEq(repayBorrow(), 0);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 1e18));
        assertEq(cToken.harnessTotalBorrows(), 0);
    }

    function testRepayBorrowBehalf() public {
        preRepay();

        // Test cases
        assertEq(comptroller.repayBorrowAllowed(), true);
        assertEq(comptroller.repayBorrowVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessAccountBorrows(borrower), (repayAmount, 1e18));
        assertEq(cToken.harnessTotalBorrows(), repayAmount);

        // Test repayBorrowBehalf
        assertEq(repayBorrowBehalf(), 0);
        assertEq(cToken.harnessAccountBorrows(borrower), (0, 1e18));
        assertEq(cToken.harnessTotalBorrows(), 0);
    }
}
