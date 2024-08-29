pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/ComptrollerInterface.sol";
import "../../src/InterestRateModel.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";
import "../Contracts/CErc20Harness.sol";

contract CTokenTest is Test {
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    CErc20Harness cToken;
    address root;
    address admin;
    address[] accounts;

    function setUp() public {
        root = address(this);
        admin = address(0x123);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        interestRateModel = new InterestRateModelHarness(0);
        cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
    }

    function testConstructor() public {
        vm.expectRevert("revert");
        new CErc20Harness(address(0), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));

        vm.expectRevert("revert initial exchange rate must be greater than zero.");
        new CErc20Harness(address(this), comptroller, interestRateModel, 0, "cToken", "cT", 18, payable(address(this)));

        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        assertEq(cToken.underlying(), address(this));
        assertEq(cToken.admin(), root);

        cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(admin));
        assertEq(cToken.admin(), admin);
    }

    function testNameSymbolDecimals() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "CToken Foo", "cFOO", 10, payable(address(this)));
        assertEq(cToken.name(), "CToken Foo");
        assertEq(cToken.symbol(), "cFOO");
        assertEq(cToken.decimals(), 10);
    }

    function testBalanceOfUnderlying() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 2, "cToken", "cT", 18, payable(address(this)));
        cToken.harnessSetBalance(root, 100);
        assertEq(cToken.balanceOfUnderlying(root), 200);
    }

    function testBorrowRatePerBlock() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        interestRateModel.setBorrowRate(0.05e18);
        assertEq(cToken.borrowRatePerBlock(), 0.05e18 / 2102400);
    }

    function testSupplyRatePerBlock() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        interestRateModel.setBorrowRate(0.05e18);
        cToken.harnessSetReserveFactorFresh(0.01e18);
        cToken.harnessExchangeRateDetails(1, 1, 0);
        cToken.harnessSetExchangeRate(1e18);
        assertEq(cToken.supplyRatePerBlock(), (0.05e18 * 0.99) / 2102400);
    }

    function testBorrowBalanceCurrent() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        address borrower = accounts[0];
        interestRateModel.setBorrowRate(0.001e18);
        interestRateModel.setFailBorrowRate(false);

        interestRateModel.setFailBorrowRate(true);
        vm.expectRevert("INTEREST_RATE_MODEL_ERROR");
        cToken.borrowBalanceCurrent(borrower);

        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetAccountBorrows(borrower, 5e18, 1e18);
        assertEq(cToken.borrowBalanceCurrent(borrower), 5e18);

        cToken.harnessSetAccountBorrows(borrower, 5e18, 3e18);
        cToken.harnessFastForward(5);
        assertEq(cToken.borrowBalanceCurrent(borrower), 5e18 * 3);
    }

    function testBorrowBalanceStored() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        address borrower = accounts[0];

        assertEq(cToken.borrowBalanceStored(borrower), 0);

        cToken.harnessSetAccountBorrows(borrower, 5e18, 1e18);
        assertEq(cToken.borrowBalanceStored(borrower), 5e18);

        cToken.harnessSetAccountBorrows(borrower, 5e18, 3e18);
        assertEq(cToken.borrowBalanceStored(borrower), 5e18 * 3);

        cToken.harnessSetAccountBorrows(borrower, UInt256Max(), 3e18);
        vm.expectRevert();
        cToken.borrowBalanceStored(borrower);

        cToken.harnessSetAccountBorrows(borrower, 5, 0);
        vm.expectRevert();
        cToken.borrowBalanceStored(borrower);
    }

    function testExchangeRateStored() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 2, "cToken", "cT", 18, payable(address(this)));

        assertEq(cToken.exchangeRateStored(), 2e18);

        cToken.harnessExchangeRateDetails(1, 1, 0);
        assertEq(cToken.exchangeRateStored(), 1e18);

        cToken.harnessExchangeRateDetails(100e18, 10e18, 0);
        assertEq(cToken.exchangeRateStored(), 0.1e18);

        cToken.harnessExchangeRateDetails(5e18, 0, 0);
        cToken.underlying().transfer(address(cToken), 500e18);
        assertEq(cToken.exchangeRateStored(), 100e18);

        cToken.harnessExchangeRateDetails(500e18, 500e18, 5e18);
        cToken.underlying().transfer(address(cToken), 500e18);
        assertEq(cToken.exchangeRateStored(), 1.99e18);
    }

    function testGetCash() public {
        CErc20Harness cToken = new CErc20Harness(address(this), comptroller, interestRateModel, 1, "cToken", "cT", 18, payable(address(this)));
        assertEq(cToken.getCash(), 0);
    }
}
