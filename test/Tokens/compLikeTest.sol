pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";
import "../../src/InterestRateModel.sol";
import "../Contracts/CompHarness.sol";

contract CompLikeTest is Test {
    CToken cToken;
    CompHarness comp;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](2);
        accounts[0] = address(0x123);
        accounts[1] = address(0x456);
        comp = new CompHarness();
        cToken = new CToken();
    }

    function testDelegateCompLikeToNonAdmin() public {
        vm.prank(accounts[1]);
        vm.expectRevert("only the admin may set the comp-like delegate");
        cToken._delegateCompLikeTo(accounts[1]);
    }

    function testDelegateCompLikeToAdmin() public {
        address delegatee = accounts[1];
        uint256 amount = 1;
        cToken._delegateCompLikeTo(delegatee);
        comp.transfer(address(cToken), amount);
        assertEq(comp.getCurrentVotes(delegatee), amount);
    }
}
