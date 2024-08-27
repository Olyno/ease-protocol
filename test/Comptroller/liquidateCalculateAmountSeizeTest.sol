pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/CToken.sol";
import "../../src/PriceOracle.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/ComptrollerHarness.sol";

contract LiquidateCalculateAmountSeizeTest is Test {
    ComptrollerHarness comptroller;
    CErc20Harness cTokenBorrowed;
    CErc20Harness cTokenCollateral;
    address root;
    address[] accounts;

    uint256 borrowedPrice = 2e10;
    uint256 collateralPrice = 1e18;
    uint256 repayAmount = 1e18;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint256 i = 0; i < accounts.length; i++) {
            accounts[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }

        comptroller = new ComptrollerHarness();
        cTokenBorrowed = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(0)),
            1e18,
            "cTokenBorrowed",
            "cTokenBorrowed",
            18,
            payable(address(this))
        );
        cTokenCollateral = new CErc20Harness(
            address(0),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(0)),
            1e18,
            "cTokenCollateral",
            "cTokenCollateral",
            18,
            payable(address(this))
        );

        setOraclePrice(cTokenBorrowed, borrowedPrice);
        setOraclePrice(cTokenCollateral, collateralPrice);
        cTokenCollateral.harnessExchangeRateDetails(8e10, 4e10, 0);
    }

    function setOraclePrice(CToken cToken, uint256 price) internal {
        PriceOracle priceOracle = PriceOracle(comptroller.oracle());
        priceOracle.setUnderlyingPrice(cToken, price);
    }

    function calculateSeizeTokens(
        Comptroller comptroller,
        CToken cTokenBorrowed,
        CToken cTokenCollateral,
        uint256 repayAmount
    ) internal view returns (uint256, uint256) {
        return comptroller.liquidateCalculateSeizeTokens(
            address(cTokenBorrowed),
            address(cTokenCollateral),
            repayAmount
        );
    }

    function testFailsIfEitherAssetPriceIsZero() public {
        setOraclePrice(cTokenBorrowed, 0);
        (uint256 error, uint256 seizeTokens) = calculateSeizeTokens(
            comptroller,
            cTokenBorrowed,
            cTokenCollateral,
            repayAmount
        );
        assertEq(error, uint256(ComptrollerError.PRICE_ERROR));
        assertEq(seizeTokens, 0);

        setOraclePrice(cTokenCollateral, 0);
        (error, seizeTokens) = calculateSeizeTokens(
            comptroller,
            cTokenBorrowed,
            cTokenCollateral,
            repayAmount
        );
        assertEq(error, uint256(ComptrollerError.PRICE_ERROR));
        assertEq(seizeTokens, 0);
    }

    function testFailsIfRepayAmountCausesOverflow() public {
        vm.expectRevert();
        calculateSeizeTokens(comptroller, cTokenBorrowed, cTokenCollateral, type(uint256).max);
    }

    function testFailsIfBorrowedAssetPriceCausesOverflow() public {
        setOraclePrice(cTokenBorrowed, type(uint256).max);
        vm.expectRevert();
        calculateSeizeTokens(comptroller, cTokenBorrowed, cTokenCollateral, repayAmount);
    }

    function testRevertsIfFailsToCalculateExchangeRate() public {
        cTokenCollateral.harnessExchangeRateDetails(1, 0, 10); // (1 - 10) -> underflow
        vm.expectRevert();
        calculateSeizeTokens(comptroller, cTokenBorrowed, cTokenCollateral, repayAmount);
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
            uint256[5] memory testCase = testCases[i];
            uint256 exchangeRate = testCase[0];
            uint256 borrowedPrice = testCase[1];
            uint256 collateralPrice = testCase[2];
            uint256 liquidationIncentive = testCase[3];
            uint256 repayAmount = testCase[4];

            setOraclePrice(cTokenCollateral, collateralPrice);
            setOraclePrice(cTokenBorrowed, borrowedPrice);
            comptroller._setLiquidationIncentive(liquidationIncentive);
            cTokenCollateral.harnessSetExchangeRate(exchangeRate);

            uint256 seizeAmount = repayAmount
                .mul(liquidationIncentive)
                .mul(borrowedPrice)
                .div(collateralPrice);
            uint256 seizeTokens = seizeAmount.div(exchangeRate);

            (uint256 error, uint256 seizeTokensResult) = calculateSeizeTokens(
                comptroller,
                cTokenBorrowed,
                cTokenCollateral,
                repayAmount
            );
            assertEq(error, uint256(ComptrollerError.NO_ERROR));
            assertApproxEqAbs(seizeTokensResult, seizeTokens, 1e7);
        }
    }

    function rando(uint256 min, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % (max - min) + min;
    }
}
