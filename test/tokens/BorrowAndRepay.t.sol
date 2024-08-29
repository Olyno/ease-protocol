pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CToken.sol";
import "../../contracts/ComptrollerInterface.sol";
import "../../contracts/InterestRateModel.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";
import "../Contracts/CErc20Harness.sol";

contract BorrowAndRepayTest is Test {
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    CErc20Harness cToken;
    address root;
    address borrower;
    address benefactor;
    address[] accounts;

    uint borrowAmount = 10e3;
    uint repayAmount = 10e2;

    function setUp() public {
        root = address(this);
        borrower = address(1);
        benefactor = address(2);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        interestRateModel = new InterestRateModelHarness(0);
        cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
    }

    function preBorrow() internal {
        comptroller.setBorrowAllowed(true);
        comptroller.setBorrowVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetFailTransferToAddress(borrower, false);
        cToken.harnessSetAccountBorrows(borrower, 0, 0);
        cToken.harnessSetTotalBorrows(0);
        cToken.harnessSetBalance(address(cToken), borrowAmount);
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
        cToken.harnessSetFailTransferFromAddress(benefactor, false);
        cToken.harnessSetFailTransferFromAddress(borrower, false);
        cToken.harnessSetAccountBorrows(borrower, 1, 1);
        cToken.harnessSetTotalBorrows(repayAmount);
        cToken.harnessSetBalance(benefactor, repayAmount);
        cToken.harnessSetBalance(borrower, repayAmount);
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
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("borrowFresh()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("borrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetTotalBorrows(type(uint).max);
        (success, data) = address(cToken).call(abi.encodeWithSignature("borrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferToAddress(borrower, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("borrowFresh()"));
        assertTrue(!success);
    }

    function testBorrow() public {
        preBorrow();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("borrow()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("borrow()"));
        assertTrue(!success);
    }

    function testRepayBorrowFresh() public {
        preRepay();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("repayBorrowFresh()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("repayBorrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetTotalBorrows(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("repayBorrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferFromAddress(benefactor, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("repayBorrowFresh()"));
        assertTrue(!success);
    }

    function testRepayBorrow() public {
        preRepay();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("repayBorrow()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("repayBorrow()"));
        assertTrue(!success);
    }

    function testRepayBorrowBehalf() public {
        preRepay();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("repayBorrowBehalf()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("repayBorrowBehalf()"));
        assertTrue(!success);
    }
}
