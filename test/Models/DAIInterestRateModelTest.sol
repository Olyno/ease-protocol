pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/DAIInterestRateModelV3.sol";
import "../../src/MockPot.sol";
import "../../src/MockJug.sol";

contract DAIInterestRateModelTest is Test {
    DAIInterestRateModelV3 daiIRM;
    MockPot pot;
    MockJug jug;

    uint256 constant secondsPerYear = 60 * 60 * 24 * 365;
    uint256 constant blocksPerYear = 2102400;

    function setUp() public {
        pot = new MockPot();
        jug = new MockJug();
        daiIRM = new DAIInterestRateModelV3(
            0.8e18,
            0.9e18,
            address(pot),
            address(jug),
            address(this)
        );
    }

    function testGetBorrowRate() public {
        uint256[6][] memory testCases = new uint256[6][](12);
        testCases[0] = [0.02e27, 0.05e27, 0.005e27, 500, 100, 0];
        testCases[1] = [0.02e27, 0.05e27, 0.005e27, 1000, 900, 0];
        testCases[2] = [0.02e27, 0.05e27, 0.005e27, 1000, 950, 0];
        testCases[3] = [0.02e27, 0.05e27, 0.005e27, 500, 100, 0];
        testCases[4] = [0.02e27, 0.05e27, 0.005e27, 3e18, 5e18, 0];
        testCases[5] = [0.02e27, 0.05e27, 0.005e27, 5e18, 3e18, 0];
        testCases[6] = [0.02e27, 0.05e27, 0.005e27, 500, 3e18, 0];
        testCases[7] = [0.02e27, 0.05e27, 0.005e27, 0, 500, 100];
        testCases[8] = [0.02e27, 0.05e27, 0.005e27, 500, 0, 0];
        testCases[9] = [0.02e27, 0.05e27, 0.005e27, 0, 0, 0];
        testCases[10] = [0.02e27, 0.05e27, 0.005e27, 3e18, 500, 0];
        testCases[11] = [0.055e27, 0.18e27, 0.005e27, 500, 100, 0];

        for (uint256 i = 0; i < testCases.length; i++) {
            uint256 dsr = testCases[i][0];
            uint256 duty = testCases[i][1];
            uint256 base = testCases[i][2];
            uint256 cash = testCases[i][3];
            uint256 borrows = testCases[i][4];
            uint256 reserves = testCases[i][5];

            uint256 onePlusPerSecondDsr = 1e27 + (dsr / secondsPerYear);
            uint256 onePlusPerSecondDuty = 1e27 + (duty / secondsPerYear);
            uint256 perSecondBase = base / secondsPerYear;

            pot.setDsr(onePlusPerSecondDsr);
            jug.setDuty(onePlusPerSecondDuty);
            jug.setBase(perSecondBase);

            uint256 expected = baseRoofRateFn(
                onePlusPerSecondDsr,
                onePlusPerSecondDuty,
                perSecondBase,
                0.8e18,
                0.9e18,
                cash,
                borrows,
                reserves
            );

            uint256 actual = daiIRM
