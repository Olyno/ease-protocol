pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/InterestRateModel.sol";
import "../Utils/Compound.sol";

contract MintAndRedeemTest is Test {
    CToken cToken;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
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
        minter = address(1);
        redeemer = address(2);
        accounts = new address[](10);
        for (uint i = 0; i < 10; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
        comptroller = new Comptroller();
        interestRateModel = new InterestRateModel();
        cToken = new CToken(address(interestRateModel), address(comptroller), address(this), 1, "CToken", "CTK", 18);
    }

    function preMint() internal {
        comptroller.setMintAllowed(true);
        comptroller.setMintVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetFailTransferFromAddress(minter, false);
        cToken.harnessSetBalance(minter, 0);
        cToken.harnessSetExchangeRate(exchangeRate);
    }

    function mintFresh() internal returns (uint) {
        return cToken.harnessMintFresh(minter, mintAmount);
    }

    function preRedeem() internal {
        comptroller.setRedeemAllowed(true);
        comptroller.setRedeemVerify(true);
        interestRateModel.setFailBorrowRate(false);
        cToken.harnessSetBalance(redeemer, redeemTokens);
        cToken.harnessSetFailTransferToAddress(redeemer, false);
        cToken.harnessSetExchangeRate(exchangeRate);
    }

    function redeemFreshTokens() internal returns (uint) {
        return cToken.harnessRedeemFresh(redeemer, redeemTokens, 0);
    }

    function redeemFreshAmount() internal returns (uint) {
        return cToken.harnessRedeemFresh(redeemer, 0, redeemAmount);
    }

    function testMintFresh() public {
        preMint();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("mintFresh()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("mintFresh()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferFromAddress(minter, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("mintFresh()"));
        assertTrue(!success);
    }

    function testMint() public {
        preMint();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("mint()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("mint()"));
        assertTrue(!success);
    }

    function testRedeemFreshTokens() public {
        preRedeem();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("redeemFreshTokens()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("redeemFreshTokens()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferToAddress(redeemer, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("redeemFreshTokens()"));
        assertTrue(!success);
    }

    function testRedeemFreshAmount() public {
        preRedeem();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("redeemFreshAmount()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("redeemFreshAmount()"));
        assertTrue(!success);

        cToken.harnessSetFailTransferToAddress(redeemer, true);
        (success, data) = address(cToken).call(abi.encodeWithSignature("redeemFreshAmount()"));
        assertTrue(!success);
    }

    function testRedeem() public {
        preRedeem();

        // Test cases
        (bool success, bytes memory data) = address(cToken).call(abi.encodeWithSignature("redeem()"));
        assertTrue(success);
        assertEq(abi.decode(data, (uint)), 0);

        cToken.harnessFastForward(1);
        (success, data) = address(cToken).call(abi.encodeWithSignature("redeem()"));
        assertTrue(!success);
    }
}
