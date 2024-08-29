pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";
import "../Utils/Compound.sol";

contract LiquidateCalculateAmountSeizeTest is Test {
    Comptroller comptroller;
    CToken cTokenBorrowed;
    CToken cTokenCollateral;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        comptroller = new Comptroller();
        cTokenBorrowed = Compound.makeCToken(address(comptroller), true);
        cTokenCollateral = Compound.makeCToken(address(comptroller), true);
    }

    function testFailsIfEitherAssetPriceIsZero() public {
        Compound.setOraclePrice(address(cTokenBorrowed), 0);
        (uint256 error, uint256 seizeTokens) = comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), 1e18);
        assertEq(error, uint256(Comptroller.Error.PRICE_ERROR));
        assertEq(seizeTokens, 0);

        Compound.setOraclePrice(address(cTokenCollateral), 0);
        (error, seizeTokens) = comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), 1e18);
        assertEq(error, uint256(Comptroller.Error.PRICE_ERROR));
        assertEq(seizeTokens, 0);
    }

    function testFailsIfRepayAmountCausesOverflow() public {
        vm.expectRevert();
        comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), type(uint256).max);
    }

    function testFailsIfBorrowedAssetPriceCausesOverflow() public {
        Compound.setOraclePrice(address(cTokenBorrowed), type(uint256).max);
        vm.expectRevert();
        comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), 1e18);
    }

    function testRevertsIfFailsToCalculateExchangeRate() public {
        Compound.setExchangeRate(address(cTokenCollateral), 1, 0, 10); // (1 - 10) -> underflow
        vm.expectRevert();
        comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), 1e18);
    }

    function testReturnsCorrectValue() public {
        uint256[5][6] memory testCases = [
            [1e18, 1e18, 1e18, 1e18, 1e18],
            [2e18, 1e18, 1e18, 1e18, 1e18],
            [2e18, 2e18, 1.42e18, 1.3e18, 2.45e18],
            [2.789e18, 5.230480842e18, 771.32e18, 1.3e18, 10002.45e18],
            [7.009232529961056e24, 2.5278726317240445e24, 2.6177112093242585e23, 1179713989619784000, 7.790468414639561e24],
            [rando(0, 1e25), rando(0, 1e25), rando(1, 1e25), rando(1e18, 1.5e18), rando(0, 1e25)]
        ];

        for (uint256 i = 0; i < testCases.length; i++) {
            uint256 exchangeRate = testCases[i][0];
            uint256 borrowedPrice = testCases[i][1];
            uint256 collateralPrice = testCases[i][2];
            uint256 liquidationIncentive = testCases[i][3];
            uint256 repayAmount = testCases[i][4];

            Compound.setOraclePrice(address(cTokenCollateral), collateralPrice);
            Compound.setOraclePrice(address(cTokenBorrowed), borrowedPrice);
            comptroller._setLiquidationIncentive(liquidationIncentive);
            Compound.setExchangeRate(address(cTokenCollateral), exchangeRate);

            uint256 seizeAmount = repayAmount * liquidationIncentive * borrowedPrice / collateralPrice;
            uint256 seizeTokens = seizeAmount / exchangeRate;

            (uint256 error, uint256 seizeTokensResult) = comptroller.liquidateCalculateSeizeTokens(address(cTokenBorrowed), address(cTokenCollateral), repayAmount);
            assertEq(error, uint256(Comptroller.Error.NO_ERROR));
            assertApproxEqAbs(seizeTokensResult, seizeTokens, 1e7);
        }
    }

    function rando(uint256 min, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % (max - min) + min;
    }
}
