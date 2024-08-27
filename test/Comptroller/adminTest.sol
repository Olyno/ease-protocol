pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/Unitroller.sol";

contract AdminTest is Test {
    Comptroller comptroller;
    Unitroller unitroller;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](2);
        accounts[0] = address(0x123);
        accounts[1] = address(0x456);
        unitroller = new Unitroller();
        comptroller = new Comptroller();
    }

    function testAdmin() public {
        assertEq(unitroller.admin(), root);
    }

    function testPendingAdmin() public {
        assertEq(unitroller.pendingAdmin(), address(0));
    }

    function testSetPendingAdmin() public {
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        unitroller._setPendingAdmin(accounts[0]);

        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), address(0));
    }

    function testSetPendingAdminSuccess() public {
        unitroller._setPendingAdmin(accounts[0]);

        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), accounts[0]);
    }

    function testSetPendingAdminTwice() public {
        unitroller._setPendingAdmin(accounts[0]);
        unitroller._setPendingAdmin(accounts[1]);

        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), accounts[1]);
    }

    function testSetPendingAdminEvent() public {
        vm.expectEmit(true, true, true, true);
        emit NewPendingAdmin(address(0), accounts[0]);
        unitroller._setPendingAdmin(accounts[0]);
    }

    function testAcceptAdminFailZero() public {
        vm.expectRevert("UNAUTHORIZED");
        unitroller._acceptAdmin();

        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), address(0));
    }

    function testAcceptAdminFailNotPending() public {
        unitroller._setPendingAdmin(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        unitroller._acceptAdmin();

        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), accounts[0]);
    }

    function testAcceptAdminSuccess() public {
        unitroller._setPendingAdmin(accounts[0]);
        vm.prank(accounts[0]);
        unitroller._acceptAdmin();

        assertEq(unitroller.admin(), accounts[0]);
        assertEq(unitroller.pendingAdmin(), address(0));
    }

    function testAcceptAdminEvent() public {
        unitroller._setPendingAdmin(accounts[0]);
        vm.prank(accounts[0]);
        vm.expectEmit(true, true, true, true);
        emit NewAdmin(root, accounts[0]);
        emit NewPendingAdmin(accounts[0], address(0));
        unitroller._acceptAdmin();
    }
}
