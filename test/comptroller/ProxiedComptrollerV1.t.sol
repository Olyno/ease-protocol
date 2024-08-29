pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";
import "../../contracts/PriceOracle.sol";

contract ProxiedComptrollerV1Test is Test {
    Comptroller unitroller;
    Comptroller brains;
    PriceOracle oracle;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        oracle = new PriceOracle();
        brains = new Comptroller();
        unitroller = new Comptroller();
    }

    function initializeBrains(PriceOracle priceOracle, uint256 closeFactor, uint256 maxAssets) internal returns (Comptroller) {
        unitroller._setPendingImplementation(address(brains));
        brains._become(address(unitroller), address(priceOracle), closeFactor, maxAssets, false);
        return Comptroller(address(unitroller));
    }

    function reinitializeBrains() internal returns (Comptroller) {
        unitroller._setPendingImplementation(address(brains));
        brains._become(address(unitroller), address(0), 0, 0, true);
        return Comptroller(address(unitroller));
    }

    function testDelegatingToComptrollerV1() public {
        uint256 closeFactor = 0.051e18;
        uint256 maxAssets = 10;
        Comptroller unitrollerAsComptroller = initializeBrains(oracle, 0.06e18, 30);
        CToken cToken = Compound.makeCToken(address(unitrollerAsComptroller));

        // Test becoming brains sets initial state
        vm.expectRevert("change not authorized");
        brains._become(address(unitroller), address(oracle), 0, 10, false);

        assertEq(unitrollerAsComptroller.admin(), root);
        assertEq(unitrollerAsComptroller.pendingAdmin(), address(0));

        Comptroller comptroller = initializeBrains(oracle, closeFactor, maxAssets);
        assertEq(comptroller.closeFactorMantissa(), closeFactor);
        assertEq(comptroller.maxAssets(), maxAssets);

        comptroller = initializeBrains(oracle, closeFactor, maxAssets);
        assertEq(unitroller.comptrollerImplementation(), address(brains));
        assertEq(comptroller.closeFactorMantissa(), closeFactor);
        assertEq(comptroller.maxAssets(), maxAssets);

        brains = new Comptroller();
        comptroller = reinitializeBrains();
        assertEq(unitroller.comptrollerImplementation(), address(brains));
        assertEq(comptroller.closeFactorMantissa(), closeFactor);
        assertEq(comptroller.maxAssets(), maxAssets);

        vm.expectRevert("set close factor error");
        brains._become(address(unitroller), address(oracle), 0, maxAssets, false);

        comptroller = initializeBrains(oracle, closeFactor, 0);
        assertEq(comptroller.maxAssets(), 0);

        comptroller = initializeBrains(oracle, closeFactor, 5000);
        assertEq(comptroller.maxAssets(), 5000);

        // Test _setCollateralFactor
        uint256 half = 0.5e18;
        uint256 one = 1e18;

        vm.expectRevert("UNAUTHORIZED");
        unitrollerAsComptroller._setCollateralFactor(address(cToken), half);

        vm.expectRevert("MARKET_NOT_LISTED");
        unitrollerAsComptroller._setCollateralFactor(address(cToken), half);

        vm.expectRevert("INVALID_COLLATERAL_FACTOR");
        unitrollerAsComptroller._setCollateralFactor(address(cToken), one);

        vm.expectRevert("PRICE_ERROR");
        unitrollerAsComptroller._setCollateralFactor(address(cToken), half);

        cToken = Compound.makeCToken(address(unitrollerAsComptroller), true);
        oracle.setUnderlyingPrice(address(cToken), 1);
        unitrollerAsComptroller._setCollateralFactor(address(cToken), half);
        assertEq(unitrollerAsComptroller.markets(address(cToken)).collateralFactorMantissa, half);

        // Test _supportMarket
        vm.expectRevert("UNAUTHORIZED");
        unitrollerAsComptroller._supportMarket(address(cToken));

        vm.expectRevert();
        unitrollerAsComptroller._supportMarket(address(oracle));

        unitrollerAsComptroller._supportMarket(address(cToken));
        vm.expectRevert("MARKET_ALREADY_LISTED");
        unitrollerAsComptroller._supportMarket(address(cToken));

        CToken cToken1 = Compound.makeCToken(address(unitroller));
        CToken cToken2 = Compound.makeCToken(address(unitroller));
        unitrollerAsComptroller._supportMarket(address(cToken1));
        unitrollerAsComptroller._supportMarket(address(cToken2));
    }
}
