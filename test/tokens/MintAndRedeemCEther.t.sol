pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CEther.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/InterestRateModel.sol";
import "../Utils/Compound.sol";

contract MintAndRedeemCEtherTest is Test {
    CEther cToken;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
    address root;
    address minter;
    address redeemer;
    address[] accounts;

    uint256 exchangeRate = 5;
    uint256 mintAmount = 1e5;
    uint256 mintTokens = mintAmount / exchangeRate;
    uint256 redeemTokens = 10e3;
    uint256 redeemAmount = redeemTokens * exchangeRate;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
        minter = accounts[1];
        redeemer = accounts[2];
        comptroller = new Comptroller();
        interestRateModel = new InterestRateModel();
        cToken = new CEther(comptroller, interestRateModel, 1e18, "CEther", "cETH", 8, root);
    }

    function preMint() internal {
        comptroller.setMintAllowed(true);
        comptroller.setMintVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetExchangeRate(exchangeRate);
    }

    function mintExplicit() internal returns (uint) {
        return cToken.mint{value: mintAmount}();
    }

    function mintFallback() internal returns (uint) {
        (bool success, ) = address(cToken).call{value: mintAmount}("");
        require(success, "Mint failed");
        return 0;
    }

    function preRedeem() internal {
        comptroller.setRedeemAllowed(true);
        comptroller.setRedeemVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetExchangeRate(exchangeRate);
        cToken.harnessSetTotalSupply(redeemTokens);
        cToken.harnessSetBalance(redeemer, redeemTokens);
    }

    function redeemCTokens() internal returns (uint) {
        return cToken.redeem(redeemTokens);
    }

    function redeemUnderlying() internal returns (uint) {
        return cToken.redeemUnderlying(redeemAmount);
    }

    function testMintExplicit() public {
        preMint();

        // Test cases
        assertEq(comptroller.mintAllowed(), true);
        assertEq(comptroller.mintVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessExchangeRate(), exchangeRate);

        // Test mintExplicit
        uint256 beforeBalance = address(minter).balance;
        uint256 beforeCTokenBalance = cToken.balanceOf(minter);
        uint256 receipt = mintExplicit();
        uint256 afterBalance = address(minter).balance;
        uint256 afterCTokenBalance = cToken.balanceOf(minter);

        assertEq(receipt, 0);
        assertEq(afterBalance, beforeBalance - mintAmount);
        assertEq(afterCTokenBalance, beforeCTokenBalance + mintTokens);
    }

    function testMintFallback() public {
        preMint();

        // Test cases
        assertEq(comptroller.mintAllowed(), true);
        assertEq(comptroller.mintVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessExchangeRate(), exchangeRate);

        // Test mintFallback
        uint256 beforeBalance = address(minter).balance;
        uint256 beforeCTokenBalance = cToken.balanceOf(minter);
        uint256 receipt = mintFallback();
        uint256 afterBalance = address(minter).balance;
        uint256 afterCTokenBalance = cToken.balanceOf(minter);

        assertEq(receipt, 0);
        assertEq(afterBalance, beforeBalance - mintAmount);
        assertEq(afterCTokenBalance, beforeCTokenBalance + mintTokens);
    }

    function testRedeemCTokens() public {
        preRedeem();

        // Test cases
        assertEq(comptroller.redeemAllowed(), true);
        assertEq(comptroller.redeemVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessExchangeRate(), exchangeRate);
        assertEq(cToken.harnessTotalSupply(), redeemTokens);
        assertEq(cToken.harnessBalance(redeemer), redeemTokens);

        // Test redeemCTokens
        uint256 beforeBalance = address(redeemer).balance;
        uint256 beforeCTokenBalance = cToken.balanceOf(redeemer);
        uint256 receipt = redeemCTokens();
        uint256 afterBalance = address(redeemer).balance;
        uint256 afterCTokenBalance = cToken.balanceOf(redeemer);

        assertEq(receipt, 0);
        assertEq(afterBalance, beforeBalance + redeemAmount);
        assertEq(afterCTokenBalance, beforeCTokenBalance - redeemTokens);
    }

    function testRedeemUnderlying() public {
        preRedeem();

        // Test cases
        assertEq(comptroller.redeemAllowed(), true);
        assertEq(comptroller.redeemVerify(), true);
        assertEq(interestRateModel.failBorrowRate(), false);
        assertEq(cToken.harnessExchangeRate(), exchangeRate);
        assertEq(cToken.harnessTotalSupply(), redeemTokens);
        assertEq(cToken.harnessBalance(redeemer), redeemTokens);

        // Test redeemUnderlying
        uint256 beforeBalance = address(redeemer).balance;
        uint256 beforeCTokenBalance = cToken.balanceOf(redeemer);
        uint256 receipt = redeemUnderlying();
        uint256 afterBalance = address(redeemer).balance;
        uint256 afterCTokenBalance = cToken.balanceOf(redeemer);

        assertEq(receipt, 0);
        assertEq(afterBalance, beforeBalance + redeemAmount);
        assertEq(afterCTokenBalance, beforeCTokenBalance - redeemTokens);
    }
}
