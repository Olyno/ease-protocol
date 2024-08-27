pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/Unitroller.sol";
import "../../src/PriceOracle.sol";
import "../../src/CToken.sol";

contract ComptrollerTest is Test {
    Comptroller comptroller;
    Unitroller unitroller;
    Comptroller brains;
    PriceOracle oracle;
    CToken cToken;

    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](3);
        accounts[0] = address(0x1);
        accounts[1] = address(0x2);
        accounts[2] = address(0x3);

        oracle = new PriceOracle();
        brains = new Comptroller();
        unitroller = new Unitroller();

        unitroller._setPendingImplementation(address(brains));
        brains._become(address(unitroller));

        comptroller = Comptroller(address(unitroller));
        cToken = new CToken();
    }

    function testAdminAndPendingAdmin() public {
        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), address(0));
    }

    function testCloseFactorAndMaxAssets() public {
        uint closeFactor = 0.051e18;
        uint maxAssets = 10;

        comptroller._setCloseFactor(closeFactor);
        comptroller._setMaxAssets(maxAssets);

        assertEq(comptroller.closeFactorMantissa(), closeFactor);
        assertEq(comptroller.maxAssets(), maxAssets);
    }

    function testSetCollateralFactor() public {
        uint half = 0.5e18;
        uint one = 1e18;

        cToken = new CToken();
        cToken._setComptroller(address(comptroller));

        comptroller._supportMarket(address(cToken));
        oracle.setUnderlyingPrice(address(cToken), 1);

        comptroller._setCollateralFactor(address(cToken), half);
        assertEq(comptroller.markets(address(cToken)).collateralFactorMantissa, half);

        comptroller._setCollateralFactor(address(cToken), one);
        assertEq(comptroller.markets(address(cToken)).collateralFactorMantissa, one);
    }

    function testSupportMarket() public {
        cToken = new CToken();
        cToken._setComptroller(address(comptroller));

        comptroller._supportMarket(address(cToken));
        assertTrue(comptroller.markets(address(cToken)).isListed);

        CToken cToken2 = new CToken();
        cToken2._setComptroller(address(comptroller));

        comptroller._supportMarket(address(cToken2));
        assertTrue(comptroller.markets(address(cToken2)).isListed);
    }

    function testSetLiquidationIncentive() public {
        uint initialIncentive = 1e18;
        uint validIncentive = 1.1e18;

        comptroller._setLiquidationIncentive(validIncentive);
        assertEq(comptroller.liquidationIncentiveMantissa(), validIncentive);
    }

    function testSetPriceOracle() public {
        PriceOracle newOracle = new PriceOracle();

        comptroller._setPriceOracle(newOracle);
        assertEq(comptroller.oracle(), newOracle);
    }

    function testRedeemVerify() public {
        cToken = new CToken();
        cToken._setComptroller(address(comptroller));

        comptroller.redeemVerify(address(cToken), accounts[0], 5, 5);
        comptroller.redeemVerify(address(cToken), accounts[0], 5, 0);
    }
}
