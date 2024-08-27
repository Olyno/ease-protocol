pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/CToken.sol";
import "../Contracts/CErc20Harness.sol";

contract AssetsListTest is Test {
    Comptroller comptroller;
    CErc20Harness cToken1;
    CErc20Harness cToken2;
    CErc20Harness cToken3;
    address user;

    function setUp() public {
        comptroller = new Comptroller();
        cToken1 = new CErc20Harness(address(0), comptroller, InterestRateModel(address(0)), 1e18, "cToken1", "CT1", 18, payable(address(0)));
        cToken2 = new CErc20Harness(address(0), comptroller, InterestRateModel(address(0)), 1e18, "cToken2", "CT2", 18, payable(address(0)));
        cToken3 = new CErc20Harness(address(0)), comptroller, InterestRateModel(address(0)), 1e18, "cToken3", "CT3", 18, payable(address(0)));
        user = address(1);
    }

    function testEnterMarkets() public {
        address[] memory cTokens = new address[](2);
        cTokens[0] = address(cToken1);
        cTokens[1] = address(cToken2);

        uint[] memory results = comptroller.enterMarkets(cTokens);
        assertEq(results[0], 0);
        assertEq(results[1], 0);

        CToken[] memory assetsIn = comptroller.getAssetsIn(user);
        assertEq(assetsIn.length, 2);
        assertEq(address(assetsIn[0]), address(cToken1));
        assertEq(address(assetsIn[1]), address(cToken2));
    }

    function testExitMarket() public {
        address[] memory cTokens = new address[](2);
        cTokens[0] = address(cToken1);
        cTokens[1] = address(cToken2);

        comptroller.enterMarkets(cTokens);
        uint result = comptroller.exitMarket(address(cToken1));
        assertEq(result, 0);

        CToken[] memory assetsIn = comptroller.getAssetsIn(user);
        assertEq(assetsIn.length, 1);
        assertEq(address(assetsIn[0]), address(cToken2));
    }

    function testCheckMembership() public {
        address[] memory cTokens = new address[](2);
        cTokens[0] = address(cToken1);
        cTokens[1] = address(cToken2);

        comptroller.enterMarkets(cTokens);
        bool isMember = comptroller.checkMembership(user, cToken1);
        assertTrue(isMember);

        isMember = comptroller.checkMembership(user, cToken3);
        assertFalse(isMember);
    }
}
