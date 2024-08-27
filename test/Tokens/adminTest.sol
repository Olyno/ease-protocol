pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/CToken.sol";
import "../../src/Comptroller.sol";

contract AdminTest is Test {
    CToken cToken;
    Comptroller comptroller;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](2);
        accounts[0] = address(0x123);
        accounts[1] = address(0x456);
        comptroller = new Comptroller();
        cToken = new CToken();
    }

    function testAdmin() public {
        assertEq(cToken.admin(), root);
    }

    function testPendingAdmin() public {
        assertEq(cToken.pendingAdmin(), address(0));
    }

    function testSetPendingAdmin() public {
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        cToken._setPendingAdmin(accounts[0]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), address(0));
    }

    function testSetPendingAdminSuccess() public {
        cToken._setPendingAdmin(accounts[0]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), accounts[0]);
    }

    function testSetPendingAdminTwice() public {
        cToken._setPendingAdmin(accounts[0]);
        cToken._setPendingAdmin(accounts[1]);

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), accounts[1]);
    }

    function testSetPendingAdminEvent() public {
        vm.expectEmit(true, true, true, true);
        emit NewPendingAdmin(address(0), accounts[0]);
        cToken._setPendingAdmin(accounts[0]);
    }

    function testAcceptAdminFailZero() public {
        vm.expectRevert("UNAUTHORIZED");
        cToken._acceptAdmin();

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), address(0));
    }

    function testAcceptAdminFailNotPending() public {
        cToken._setPendingAdmin(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        cToken._acceptAdmin();

        assertEq(cToken.admin(), root);
        assertEq(cToken.pendingAdmin(), accounts[0]);
    }

    function testAcceptAdminSuccess() public {
        cToken._setPendingAdmin(accounts[0]);
        vm.prank(accounts[0]);
        cToken._acceptAdmin();

        assertEq(cToken.admin(), accounts[0]);
        assertEq(cToken.pendingAdmin(), address(0));
    }

    function testAcceptAdminEvent() public {
        cToken._setPendingAdmin(accounts[0]);
        vm.prank(accounts[0]);
        vm.expectEmit(true, true, true, true);
        emit NewAdmin(root, accounts[0]);
        emit NewPendingAdmin(accounts[0], address(0));
        cToken._acceptAdmin();
    }
}
