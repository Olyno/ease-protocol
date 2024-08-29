pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";

contract AssetsListTest is Test {
    Comptroller comptroller;
    CToken OMG;
    CToken ZRX;
    CToken BAT;
    CToken REP;
    CToken DAI;
    CToken SKT;
    address root;
    address customer;
    address[] accounts;

    function setUp() public {
        (root, customer, accounts) = getAccounts();
        comptroller = new Comptroller();
        OMG = makeCToken("OMG", 0.5);
        ZRX = makeCToken("ZRX", 0.5);
        BAT = makeCToken("BAT", 0.5);
        REP = makeCToken("REP", 0.5);
        DAI = makeCToken("DAI", 0.5);
        SKT = makeCToken("sketch", 0.5);
    }

    function makeCToken(string memory name, uint256 price) internal returns (CToken) {
        CToken cToken = new CToken();
        cToken.initialize(comptroller, name, name, 18, price);
        return cToken;
    }

    function checkMarkets(CToken[] memory expectedTokens) internal {
        for (uint256 i = 0; i < allTokens.length; i++) {
            bool isExpected = false;
            for (uint256 j = 0; j < expectedTokens.length; j++) {
                if (keccak256(abi.encodePacked(expectedTokens[j].symbol())) == keccak256(abi.encodePacked(allTokens[i].symbol()))) {
                    isExpected = true;
                    break;
                }
            }
            assertEq(comptroller.checkMembership(customer, allTokens[i]), isExpected);
        }
    }

    function enterAndCheckMarkets(CToken[] memory enterTokens, CToken[] memory expectedTokens, string[] memory expectedErrors) internal returns (bool) {
        (uint256[] memory reply, bool receipt) = comptroller.enterMarkets(enterTokens);
        address[] memory assetsIn = comptroller.getAssetsIn(customer);
        if (expectedErrors.length == 0) {
            expectedErrors = new string[](enterTokens.length);
            for (uint256 i = 0; i < enterTokens.length; i++) {
                expectedErrors[i] = "NO_ERROR";
            }
        }

        for (uint256 i = 0; i < reply.length; i++) {
            assertEq(reply[i], expectedErrors[i]);
        }

        assertTrue(receipt);
        assertEq(assetsIn, expectedTokens);

        checkMarkets(expectedTokens);

        return receipt;
    }

    function exitAndCheckMarkets(CToken exitToken, CToken[] memory expectedTokens, string memory expectedError) internal returns (bool) {
        (uint256 reply, bool receipt) = comptroller.exitMarket(exitToken);
        address[] memory assetsIn = comptroller.getAssetsIn(customer);
        assertEq(reply, expectedError);
        assertEq(assetsIn, expectedTokens);
        checkMarkets(expectedTokens);
        return receipt;
    }

    function testEnterMarkets() public {
        CToken[] memory enterTokens = new CToken[](1);
        enterTokens[0] = OMG;
        CToken[] memory expectedTokens = new CToken[](1);
        expectedTokens[0] = OMG;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        enterTokens[0] = ZRX;
        expectedTokens = new CToken[](2);
        expectedTokens[0] = OMG;
        expectedTokens[1] = ZRX;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        enterTokens[0] = BAT;
        expectedTokens = new CToken[](3);
        expectedTokens[0] = OMG;
        expectedTokens[1] = ZRX;
        expectedTokens[2] = BAT;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        enterTokens[0] = SKT;
        expectedTokens = new CToken[](3);
        expectedTokens[0] = OMG;
        expectedTokens[1] = ZRX;
        expectedTokens[2] = BAT;
        string[] memory expectedErrors = new string[](1);
        expectedErrors[0] = "MARKET_NOT_LISTED";
        enterAndCheckMarkets(enterTokens, expectedTokens, expectedErrors);

        comptroller._supportMarket(SKT);
        expectedTokens = new CToken[](4);
        expectedTokens[0] = OMG;
        expectedTokens[1] = ZRX;
        expectedTokens[2] = BAT;
        expectedTokens[3] = SKT;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));
    }

    function testExitMarket() public {
        CToken[] memory enterTokens = new CToken[](1);
        enterTokens[0] = OMG;
        CToken[] memory expectedTokens = new CToken[](1);
        expectedTokens[0] = OMG;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        enterTokens[0] = BAT;
        expectedTokens = new CToken[](2);
        expectedTokens[0] = OMG;
        expectedTokens[1] = BAT;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        enterTokens[0] = ZRX;
        expectedTokens = new CToken[](3);
        expectedTokens[0] = OMG;
        expectedTokens[1] = BAT;
        expectedTokens[2] = ZRX;
        enterAndCheckMarkets(enterTokens, expectedTokens, new string[](0));

        exitAndCheckMarkets(OMG, new CToken[](2), "NO_ERROR");
        exitAndCheckMarkets(BAT, new CToken[](1), "NO_ERROR");
        exitAndCheckMarkets(ZRX, new CToken[](0), "NO_ERROR");
    }

    function testEnteringFromBorrowAllowed() public {
        comptroller.borrowAllowed(OMG, customer, 1);
        address[] memory assetsIn = comptroller.getAssetsIn(customer);
        assertEq(assetsIn.length, 1);
        assertEq(assetsIn[0], OMG);
        checkMarkets(new CToken[](1));

        comptroller.borrowAllowed(BAT, customer, 1);
        assetsIn = comptroller.getAssetsIn(customer);
        assertEq(assetsIn.length, 2);
        assertEq(assetsIn[0], OMG);
        assertEq(assetsIn[1], BAT);
        checkMarkets(new CToken[](2));
    }
}
