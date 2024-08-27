pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";
import "../../src/InterestRateModel.sol";
import "../Contracts/CErc20Harness.sol";

contract CTokenTest is Test {
    CToken cToken;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
    address root;
    address admin;
    address[] accounts;

    function setUp() public {
        root = address(this);
        admin = address(0x123);
        accounts = new address[](3);
        accounts[0] = address(0x1);
        accounts[1] = address(0x2);
        accounts[2] = address(0x3);

        comptroller = new Comptroller();
        interestRateModel = new InterestRateModel();
        cToken = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            interestRateModel,
            1e18,
            "CToken Foo",
            "cFOO",
            10,
            payable(root)
        );
    }

    function testConstructor() public {
        assertEq(cToken.underlying(), address(0));
        assertEq(cToken.admin(), root);
    }

    function testNameSymbolDecimals() public {
        assertEq(cToken.name(), "CToken Foo");
        assertEq(cToken.symbol(), "cFOO");
        assertEq(cToken.decimals(), 10);
    }

    function testBalanceOfUnderlying() public {
        cToken.harnessSetBalance(root, 100);
        assertEq(cToken.balanceOfUnderlying(root), 200);
    }

    function testBorrowRatePerBlock() public {
        uint256 perBlock = cToken.borrowRatePerBlock();
        assertApproxEqAbs(perBlock * 2102400, 5e16, 1e8);
    }

    function testSupplyRatePerBlock() public {
        cToken.harnessSetReserveFactorFresh(etherMantissa(.01));
        cToken.harnessExchangeRateDetails(1, 1, 0);
        cToken.harnessSetExchangeRate(etherMantissa(1));
        uint256 perBlock = cToken.supplyRatePerBlock();
        assertApproxEqAbs(perBlock * 2102400, 0, 1e8);
    }

    function testBorrowBalanceCurrent() public {
        address borrower = accounts[0];
        cToken.harnessSetBorrowIndex(etherMantissa(1));
        cToken.harnessSetAccountBorrows(borrower, 1, 1);
        cToken.harnessSetTotalBorrows(5e18);
        assertEq(cToken.borrowBalanceCurrent(borrower), 5e18);
    }

    function testBorrowBalanceStored() public {
        address borrower = accounts[0];
        cToken.harnessSetAccountBorrows(borrower, 1, 1);
        assertEq(cToken.borrowBalanceStored(borrower), 5e18);
    }

    function testExchangeRateStored() public {
        cToken.harnessExchangeRateDetails(1, 1, 0);
        assertEq(cToken.exchangeRateStored(), etherMantissa(1));
    }

    function testGetCash() public {
        assertEq(cToken.getCash(), 0);
    }
}
