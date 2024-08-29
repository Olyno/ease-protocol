pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Comp.sol";

contract CompLikeTest is Test {
    CToken cToken;
    Comp comp;
    address root;
    address a1;

    function setUp() public {
        root = address(this);
        a1 = address(0x123);
        comp = new Comp(root);
        cToken = new CToken(address(comp), address(0), address(0), 0, "CToken", "CTK", 18);
    }

    function testDelegateCompLikeToNotAdmin() public {
        vm.prank(a1);
        vm.expectRevert("only the admin may set the comp-like delegate");
        cToken._delegateCompLikeTo(a1);
    }

    function testDelegateCompLikeToAdmin() public {
        uint256 amount = 1;
        cToken._delegateCompLikeTo(a1);
        comp.transfer(address(cToken), amount);
        assertEq(comp.getCurrentVotes(a1), amount);
    }
}
