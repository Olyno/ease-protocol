pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/InterestRateModel.sol";
import "../Contracts/InterestRateModelHarness.sol";

contract InterestRateModelTest is Test {
    InterestRateModelHarness model;
    uint256 blocksPerYear = 2102400;

    function setUp() public {
        model = new InterestRateModelHarness(0);
    }

    function testIsInterestRateModel() public {
        assertTrue(model.isInterestRateModel());
    }

    function testBorrowRate() public {
        uint256[2][10] memory rateInputs = [
            [500, 100],
            [3e18, 5e18],
            [5e18, 3e18],
            [500, 3e18],
            [0, 500],
            [500, 0],
            [0, 0],
            [3e18, 500],
            [1000e18, 310e18],
            [690e18, 310e18]
        ];

        for (uint256 i = 0; i < rateInputs.length; i++) {
            uint256 cash = rateInputs[i][0];
            uint256 borrows = rateInputs[i][1];
            uint256 reserves = 0;
            uint256 expected = whitePaperRateFn(0.1e18, 0.45e18)(cash, borrows, reserves);
            uint256 actual = model.getBorrowRate(cash, borrows, reserves);
            assertApproxEqAbs(actual, expected, 1e7);
        }
    }

    function testJumpRate() public {
        uint256[5][6] memory testCases = [
            [100, 90, 10, 20, 0],
            [100, 90, 10, 20, 10],
            [100, 90, 10, 20, 89],
            [100, 90, 10, 20, 90],
            [100, 90, 10, 20, 91],
            [100, 90, 10, 20, 100]
        ];

        for (uint256 i = 0; i < testCases.length; i++) {
            uint256 jump = testCases[i][0];
            uint256 kink = testCases[i][1];
            uint256 base = testCases[i][2];
            uint256 slope = testCases[i][3];
            uint256 util = testCases[i][4];

            uint256 expected = calculateExpectedJumpRate(jump, kink, base, slope, util);
            uint256 actual = model.getBorrowRate(0, util * 1e16, 0);
            assertApproxEqAbs(actual, expected, 1e-2);
        }
    }

    function calculateExpectedJumpRate(uint256 jump, uint256 kink, uint256 base, uint256 slope, uint256 util) internal pure returns (uint256) {
        if (util <= kink) {
            return (util * slope + base) / 100;
        } else {
            uint256 excessUtil = util - kink;
            uint256 jumpMultiplier = jump * slope;
            return ((excessUtil * jumpMultiplier) + (kink * slope) + base) / 100;
        }
    }

    function whitePaperRateFn(uint256 base, uint256 slope) internal pure returns (function(uint256, uint256, uint256) internal pure returns (uint256)) {
        return (cash, borrows, reserves) => {
            uint256 ur = utilizationRate(cash, borrows, reserves);
            return (ur * slope + base) / 2102400;
        };
    }

    function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) internal pure returns (uint256) {
        return borrows == 0 ? 0 : borrows * 1e18 / (cash + borrows - reserves);
    }
}
