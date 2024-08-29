pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/InterestRateModel.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";
import "../Contracts/CErc20Harness.sol";

contract LiquidateTest is Test {
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    CErc20Harness cToken;
    CErc20Harness cTokenCollateral;
    address root;
    address liquidator;
    address borrower;
    address[] accounts;

    uint256 repayAmount = 10e18;
    uint256 seizeTokens = repayAmount * 4;

    function setUp() public {
        root = address(this);
        liquidator = address(1);
        borrower = address(2);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        interestRateModel = new InterestRateModelHarness(0);
        cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        cTokenCollateral = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cTokenCollateral", "cTC", 18, payable(address(this)));
    }

    function preLiquidate() internal {
        comptroller.setLiquidateBorrowAllowed(true);
        comptroller.setLiquidateBorrowVerify(true);
        comptroller.setRepayBorrowAllowed(true);
        comptroller.setRepayBorrowVerify(true);
        comptroller.setSeizeAllowed(true);
        comptroller.setSeizeVerify(true);
        comptroller.setFailCalculateSeizeTokens(false);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetFailTransferFromAddress(liquidator, false);
        cTokenCollateral.harnessSetFailTransferFromAddress(liquidator, false);
        cTokenCollateral.harnessSetTotalSupply(10e18);
        cTokenCollateral.harnessSetBalance(liquidator, 0);
        cTokenCollateral.harnessSetBalance(borrower, seizeTokens);
        cTokenCollateral.harnessSetBorrowBalance(borrower, 0, 1);
        cToken.harnessSetBorrowBalance(borrower, 1, repayAmount);
        cToken.harnessSetBalance(liquidator, repayAmount);
    }

    function liquidateFresh() internal returns (uint) {
        return cToken.harnessLiquidateBorrowFresh(liquidator, borrower, repayAmount, cTokenCollateral);
    }

    function liquidate() internal returns (uint) {
        cToken.harnessFastForward(1);
        cTokenCollateral.harnessFastForward(1);
        return cToken.liquidateBorrow(borrower, repayAmount, cTokenCollateral);
    }

    function seize() internal returns (uint) {
        return cToken.seize(liquidator, borrower, seizeTokens);
    }

    function testLiquidateBorrowFresh() public {
        preLiquidate();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrowFresh()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetTotalBorrows(type(uint).max);
        (success, data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrowFresh()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferFromAddress(liquidator, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrowFresh()"));
        assertTrue(!success);
    }

    function testLiquidateBorrow() public {
        preLiquidate();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrow()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("liquidateBorrow()"));
        assertTrue(!success);
    }

    function testSeize() public {
        preLiquidate();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("seize()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("seize()"));
        assertTrue(!success);
    }
}
