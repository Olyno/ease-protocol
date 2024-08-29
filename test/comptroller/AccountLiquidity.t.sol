pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";
import "../Utils/Compound.sol";

contract AccountLiquidityTest is Test {
    Comptroller comptroller;
    CToken cToken;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        comptroller = new Comptroller();
    }

    function testFailsIfPriceNotSet() public {
        cToken = Compound.makeCToken(address(comptroller), true);
        Compound.enterMarkets(address(comptroller), address(cToken), accounts[1]);
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(accounts[1]);
        assertEq(error, uint256(Comptroller.Error.PRICE_ERROR));
    }

    function testAllowsBorrowUpToCollateralFactor() public {
        uint256 collateralFactor = 0.5 * 1e18;
        uint256 underlyingPrice = 1 * 1e18;
        address user = accounts[1];
        uint256 amount = 1e6 * 1e18;
        cToken = Compound.makeCToken(address(comptroller), true, collateralFactor, underlyingPrice);

        uint256 error;
        uint256 liquidity;
        uint256 shortfall;

        // not in market yet, hypothetical borrow should have no effect
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken), 0, amount);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);

        Compound.enterMarkets(address(comptroller), address(cToken), user);
        Compound.quickMint(address(cToken), user, amount);

        // total account liquidity after supplying `amount`
        (error, liquidity, shortfall) = comptroller.getAccountLiquidity(user);
        assertEq(liquidity, amount * collateralFactor);
        assertEq(shortfall, 0);

        // hypothetically borrow `amount`, should shortfall over collateralFactor
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken), 0, amount);
        assertEq(liquidity, 0);
        assertEq(shortfall, amount * (1e18 - collateralFactor));

        // hypothetically redeem `amount`, should be back to even
        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken), amount, 0);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testAllowsEnteringThreeMarkets() public {
        uint256 amount1 = 1e6 * 1e18;
        uint256 amount2 = 1e3 * 1e18;
        address user = accounts[1];
        uint256 cf1 = 0.5 * 1e18;
        uint256 cf2 = 0.666 * 1e18;
        uint256 cf3 = 0;
        uint256 up1 = 3 * 1e18;
        uint256 up2 = 2.718 * 1e18;
        uint256 up3 = 1 * 1e18;
        uint256 c1 = amount1 * cf1 * up1;
        uint256 c2 = amount2 * cf2 * up2;
        uint256 collateral = c1 + c2;
        CToken cToken1 = Compound.makeCToken(address(comptroller), true, cf1, up1);
        CToken cToken2 = Compound.makeCToken(address(comptroller), true, cf2, up2);
        CToken cToken3 = Compound.makeCToken(address(comptroller), true, cf3, up3);

        Compound.enterMarkets(address(comptroller), address(cToken1), user);
        Compound.enterMarkets(address(comptroller), address(cToken2), user);
        Compound.enterMarkets(address(comptroller), address(cToken3), user);
        Compound.quickMint(address(cToken1), user, amount1);
        Compound.quickMint(address(cToken2), user, amount2);

        uint256 error;
        uint256 liquidity;
        uint256 shortfall;

        (error, liquidity, shortfall) = comptroller.getAccountLiquidity(user);
        assertEq(error, 0);
        assertEq(liquidity, collateral);
        assertEq(shortfall, 0);

        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), c2, 0);
        assertEq(liquidity, collateral);
        assertEq(shortfall, 0);

        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), 0, c2);
        assertEq(liquidity, c1);
        assertEq(shortfall, 0);

        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken3), 0, collateral + c1);
        assertEq(liquidity, 0);
        assertEq(shortfall, c1);

        (error, liquidity, shortfall) = comptroller.getHypotheticalAccountLiquidity(user, address(cToken1), amount1, 0);
        assertEq(liquidity, c2);
        assertEq(shortfall, 0);
    }

    function testGetAccountLiquidity() public {
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(accounts[0]);
        assertEq(error, 0);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testGetHypotheticalAccountLiquidity() public {
        cToken = Compound.makeCToken(address(comptroller), true);
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getHypotheticalAccountLiquidity(accounts[0], address(cToken), 0, 0);
        assertEq(error, 0);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testReturnsCollateralFactorTimesDollarAmount() public {
        uint256 collateralFactor = 0.5 * 1e18;
        uint256 exchangeRate = 1 * 1e18;
        uint256 underlyingPrice = 1 * 1e18;
        cToken = Compound.makeCToken(address(comptroller), true, collateralFactor, exchangeRate, underlyingPrice);
        address from = accounts[0];
        uint256 balance = 1e7 * 1e18;
        uint256 amount = 1e6 * 1e18;
        Compound.enterMarkets(address(comptroller), address(cToken), from);
        Compound.setBalance(address(cToken.underlying()), from, balance);
        Compound.approve(address(cToken.underlying()), address(cToken), balance, from);
        Compound.mint(address(cToken), amount, from);
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getHypotheticalAccountLiquidity(from, address(cToken), 0, 0);
        assertEq(error, 0);
        assertEq(liquidity, amount * collateralFactor * exchangeRate * underlyingPrice);
        assertEq(shortfall, 0);
    }
}
