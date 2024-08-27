pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../Contracts/CErc20Harness.sol";
import "../Contracts/ComptrollerHarness.sol";
import "../Contracts/InterestRateModelHarness.sol";
import "../Contracts/ERC20Harness.sol";

contract MintAndRedeemTest is Test {
    CErc20Harness cToken;
    ComptrollerHarness comptroller;
    InterestRateModelHarness interestRateModel;
    ERC20Harness underlying;
    address root;
    address minter;
    address redeemer;
    address[] accounts;

    uint256 exchangeRate = 50e3;
    uint256 mintAmount = 10e4;
    uint256 mintTokens = mintAmount / exchangeRate;
    uint256 redeemTokens = 10e3;
    uint256 redeemAmount = redeemTokens * exchangeRate;

    function setUp() public {
        root = address(this);
        minter = address(0x123);
        redeemer = address(0x456);
        accounts = new address[](2);
        accounts[0] = minter;
        accounts[1] = redeemer;

        comptroller = new ComptrollerHarness();
        interestRateModel = new InterestRateModelHarness();
        underlying = new ERC20Harness(mintAmount, "UnderlyingToken", 18, "UTK");
        cToken = new CErc20Harness(
            address(underlying),
            ComptrollerInterface(address(comptroller)),
            InterestRateModel(address(interestRateModel)),
            exchangeRate,
            "CToken",
            "CTK",
            18,
            payable(address(this))
        );
    }

    function testMintFresh() public {
        preMint(cToken, minter, mintAmount, mintTokens, exchangeRate);
        assertEq(cToken.mintFresh(minter, mintAmount), 0);
    }

    function testMint() public {
        preMint(cToken, minter, mintAmount, mintTokens, exchangeRate);
        assertEq(cToken.mint(mintAmount), 0);
    }

    function testRedeemFreshTokens() public {
        preRedeem(cToken, redeemer, redeemTokens, redeemAmount, exchangeRate);
        assertEq(cToken.redeemFresh(redeemer, redeemTokens, 0), 0);
    }

    function testRedeemFreshAmount() public {
        preRedeem(cToken, redeemer, redeemTokens, redeemAmount, exchangeRate);
        assertEq(cToken.redeemFresh(redeemer, 0, redeemAmount), 0);
    }

    function testRedeem() public {
        preRedeem(cToken, redeemer, redeemTokens, redeemAmount, exchangeRate);
        assertEq(cToken.redeem(redeemTokens), 0);
    }

    function testRedeemUnderlying() public {
        preRedeem(cToken, redeemer, redeemTokens, redeemAmount, exchangeRate);
        assertEq(cToken.redeemUnderlying(redeemAmount), 0);
    }

    function preMint(
        CErc20Harness cToken,
        address minter,
        uint256 mintAmount,
        uint256 mintTokens,
        uint256 exchangeRate
    ) internal {
        underlying.approve(address(cToken), mintAmount);
        comptroller.setMintAllowed(true);
        comptroller.setMintVerify(true);
        interestRateModel.setFailBorrowRate(false);
        underlying.harnessSetFailTransferFromAddress(minter, false);
        cToken.harnessSetBalance(minter, 0);
        cToken.harnessSetExchangeRate(exchangeRate);
    }

    function preRedeem(
        CErc20Harness cToken,
        address redeemer,
        uint256 redeemTokens,
        uint256 redeemAmount,
        uint256 exchangeRate
    ) internal {
        underlying.harnessSetBalance(address(cToken), redeemAmount);
        underlying.harnessSetBalance(redeemer, 0);
        underlying.harnessSetFailTransferToAddress(redeemer, false);
        cToken.harnessSetExchangeRate(exchangeRate);
        cToken.harnessSetTotalSupply(redeemTokens);
        cToken.harnessSetBalance(redeemer, redeemTokens);
        comptroller.setRedeemAllowed(true);
        comptroller.setRedeemVerify(true);
        interestRateModel.setFailBorrowRate(false);
    }
}
