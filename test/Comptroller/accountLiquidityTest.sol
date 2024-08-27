pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/CToken.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/CEtherHarness.sol";
import "../Contracts/CompHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";
import "../Contracts/PriceOracle.sol";
import "../Contracts/FixedPriceOracle.sol";
import "../Contracts/Unitroller.sol";
import "../Contracts/ComptrollerInterface.sol";
import "../Contracts/ComptrollerStorage.sol";
import "../Contracts/ExponentialNoError.sol";
import "../Contracts/ErrorReporter.sol";

contract ComptrollerTest is Test {
    ComptrollerHarness comptroller;
    CErc20Harness cToken;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
        comptroller = new ComptrollerHarness();
        cToken = new CErc20Harness();
    }

    function testLiquidityFailsIfPriceNotSet() public {
        cToken._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken._supportMarket();
        address user = accounts[1];
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(user);
        assertEq(error, uint(Error.PRICE_ERROR));
    }

    function testBorrowUpToCollateralFactor() public {
        uint collateralFactor = 0.5 * 1e18;
        uint underlyingPrice = 1 * 1e18;
        address user = accounts[1];
        uint amount = 1e6 * 1e18;
        cToken._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken._supportMarket();
        cToken._setCollateralFactor(collateralFactor);
        cToken._setUnderlyingPrice(underlyingPrice);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);
        cToken.mint(user, amount);
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(user);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, amount * collateralFactor / 1e18);
        assertEq(shortfall, 0);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken), 0, amount);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, 0);
        assertEq(shortfall, amount * (1e18 - collateralFactor) / 1e18);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken), amount, 0);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testEnteringMultipleMarkets() public {
        uint amount1 = 1e6 * 1e18;
        uint amount2 = 1e3 * 1e18;
        address user = accounts[1];
        uint cf1 = 0.5 * 1e18;
        uint cf2 = 0.666 * 1e18;
        uint cf3 = 0;
        uint up1 = 3 * 1e18;
        uint up2 = 2.718 * 1e18;
        uint up3 = 1 * 1e18;
        uint c1 = amount1 * cf1 * up1 / 1e18;
        uint c2 = amount2 * cf2 * up2 / 1e18;
        uint collateral = c1 + c2;
        CErc20Harness cToken1 = new CErc20Harness();
        CErc20Harness cToken2 = new CErc20Harness();
        CErc20Harness cToken3 = new CErc20Harness();
        cToken1._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken2._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken3._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken1._supportMarket();
        cToken2._supportMarket();
        cToken3._supportMarket();
        cToken1._setCollateralFactor(cf1);
        cToken2._setCollateralFactor(cf2);
        cToken3._setCollateralFactor(cf3);
        cToken1._setUnderlyingPrice(up1);
        cToken2._setUnderlyingPrice(up2);
        cToken3._setUnderlyingPrice(up3);
        address[] memory cTokens = new address[](3);
        cTokens[0] = address(cToken1);
        cTokens[1] = address(cToken2);
        cTokens[2] = address(cToken3);
        comptroller.enterMarkets(cTokens);
        cToken1.mint(user, amount1);
        cToken2.mint(user, amount2);
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(user);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, collateral);
        assertEq(shortfall, 0);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), c2, 0);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, collateral);
        assertEq(shortfall, 0);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), 0, c2);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, c1);
        assertEq(shortfall, 0);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), 0, collateral + c1);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, 0);
        assertEq(shortfall, c1);
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken1), amount1, 0);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, c2);
        assertEq(shortfall, 0);
    }

    function testGetAccountLiquidity() public {
        ComptrollerHarness comptroller = new ComptrollerHarness();
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(accounts[0]);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testGetHypotheticalAccountLiquidity() public {
        CErc20Harness cToken = new CErc20Harness();
        ComptrollerHarness comptroller = new ComptrollerHarness();
        (uint error, uint liquidity, uint shortfall) = comptroller.getHypotheticalAccountLiquidity(accounts[0], address(cToken), 0, 0);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testCollateralFactorTimesDollarAmount() public {
        uint collateralFactor = 0.5 * 1e18;
        uint exchangeRate = 1 * 1e18;
        uint underlyingPrice = 1 * 1e18;
        CErc20Harness cToken = new CErc20Harness();
        cToken._setComptroller(ComptrollerInterface(address(comptroller)));
        cToken._supportMarket();
        cToken._setCollateralFactor(collateralFactor);
        cToken._setExchangeRate(exchangeRate);
        cToken._setUnderlyingPrice(underlyingPrice);
        address from = accounts[0];
        uint balance = 1e7 * 1e18;
        uint amount = 1e6 * 1e18;
        cToken.mint(from, amount);
        (uint error, uint liquidity, uint shortfall) = comptroller.getHypotheticalAccountLiquidity(from, address(cToken), 0, 0);
        assertEq(error, uint(Error.NO_ERROR));
        assertEq(liquidity, amount * collateralFactor * exchangeRate * underlyingPrice / 1e18);
        assertEq(shortfall, 0);
    }
}
