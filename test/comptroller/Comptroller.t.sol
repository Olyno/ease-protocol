pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/PriceOracle.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Token.sol";

contract ComptrollerTest is Test {
    Comptroller comptroller;
    PriceOracle oldOracle;
    PriceOracle newOracle;
    CToken cToken;
    Token asset;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        comptroller = new Comptroller();
        oldOracle = comptroller.priceOracle();
        newOracle = new PriceOracle();
    }

    function testConstructor() public {
        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), address(0));
        assertEq(comptroller.closeFactorMantissa(), 0.051e18);
    }

    function testSetLiquidationIncentive() public {
        uint256 initialIncentive = 1e18;
        uint256 validIncentive = 1.1e18;
        uint256 tooSmallIncentive = 0.99999e18;
        uint256 tooLargeIncentive = 1.50000001e18;

        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setLiquidationIncentive(initialIncentive);

        assertEq(comptroller.liquidationIncentiveMantissa(), initialIncentive);

        comptroller._setLiquidationIncentive(validIncentive);

        assertEq(comptroller.liquidationIncentiveMantissa(), validIncentive);
    }

    function testSetPriceOracle() public {
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setPriceOracle(newOracle);

        assertEq(comptroller.oracle(), oldOracle);

        vm.expectRevert("oracle method isPriceOracle returned false");
        comptroller._setPriceOracle(comptroller);

        vm.expectRevert("oracle method isPriceOracle returned false");
        comptroller._setPriceOracle(newOracle);

        comptroller._setPriceOracle(newOracle);

        assertEq(comptroller.oracle(), newOracle);
    }

    function testSetCloseFactor() public {
        vm.prank(accounts[0]);
        vm.expectRevert("only admin can set close factor");
        comptroller._setCloseFactor(1);
    }

    function testSetCollateralFactor() public {
        uint256 half = 0.5e18;
        uint256 one = 1e18;

        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setCollateralFactor(cToken, half);

        vm.expectRevert("MARKET_NOT_LISTED");
        comptroller._setCollateralFactor(cToken, half);

        vm.expectRevert("PRICE_ERROR");
        comptroller._setCollateralFactor(cToken, half);

        comptroller._supportMarket(cToken);
        comptroller._setCollateralFactor(cToken, half);

        assertEq(comptroller.markets(cToken).collateralFactorMantissa, half);
    }

    function testSupportMarket() public {
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._supportMarket(cToken);

        vm.expectRevert();
        comptroller._supportMarket(asset);

        comptroller._supportMarket(cToken);

        vm.expectRevert("MARKET_ALREADY_LISTED");
        comptroller._supportMarket(cToken);

        CToken cToken2 = new CToken();
        comptroller._supportMarket(cToken2);
    }

    function testRedeemVerify() public {
        comptroller.redeemVerify(cToken, accounts[0], 0, 0);
        comptroller.redeemVerify(cToken, accounts[0], 5, 5);

        vm.expectRevert("redeemTokens zero");
        comptroller.redeemVerify(cToken, accounts[0], 5, 0);
    }
}
