pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/InterestRateModel.sol";
import "../../src/JumpRateModel.sol";
import "../../src/JumpRateModelV2.sol";

contract InterestRateModelTest is Test {
    InterestRateModel model;
    JumpRateModel jumpModel;
    JumpRateModelV2 jumpModelV2;

    function setUp() public {
        model = new JumpRateModel(0.1e18, 0.45e18, 5e18, 0.9e18);
        jumpModel = new JumpRateModel(0.1e18, 0.45e18, 5e18, 0.9e18);
        jumpModelV2 = new JumpRateModelV2(0.1e18, 0.45e18, 5e18, 0.9e18, address(this));
    }

    function testIsInterestRateModel() public {
        assertTrue(model.isInterestRateModel());
    }

    function testBorrowRate() public {
        uint cash = 500;
        uint borrows = 100;
        uint reserves = 0;
        uint expectedRate = (borrows * 0.45e18 / (cash + borrows - reserves) + 0.1e18) / 2102400;
        assertEq(model.getBorrowRate(cash, borrows, reserves), expectedRate);
    }

    function testJumpRate() public {
        uint cash = 500;
        uint borrows = 100;
        uint reserves = 0;
        uint expectedRate = (borrows * 0.45e18 / (cash + borrows - reserves) + 0.1e18) / 2102400;
        assertEq(jumpModel.getBorrowRate(cash, borrows, reserves), expectedRate);
    }

    function testJumpRateV2() public {
        uint cash = 500;
        uint borrows = 100;
        uint reserves = 0;
        uint expectedRate = (borrows * 0.45e18 / (cash + borrows - reserves) + 0.1e18) / 2102400;
        assertEq(jumpModelV2.getBorrowRate(cash, borrows, reserves), expectedRate);
    }
}
