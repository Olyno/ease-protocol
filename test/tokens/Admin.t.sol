pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Unitroller.sol";

contract AdminTest is Test {
    Unitroller cToken;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](2);
        accounts[0] = address(0x123);
        accounts[1] = address(0x456);
        cToken = new Unitroller();
    }

    function testAdmin() public {
        assertEq(cToken.admin(), root);
    }

    function testPendingAdmin() public {
        assertEq(cToken.pendingAdmin(), address(0));
    }

    function testSetPendingAdmin() public {
        vm.prank(accounts[0]);
        vm.expectRevert("only admin can set pending admin");
        cToken._setPendingAdmin(accounts[0]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), address(0));

        cToken._setPendingAdmin(accounts[0]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), accounts[0]);

        cToken._setPendingAdmin(accounts[1]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), accounts[1]);
    }

    function testAcceptAdmin() public {
        vm.expectRevert("pending admin must be set");
        cToken._acceptAdmin();

        cToken._setPendingAdmin(accounts[0]);

        vm.prank(accounts[0]);
        cToken._acceptAdmin();

        assertEq(cToken.admin(), accounts[0]);
        assertEq(cToken.pendingAdmin(), address(0));
    }
}
