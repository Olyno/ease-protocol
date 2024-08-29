pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Unitroller.sol";

contract AdminTest is Test {
    Unitroller comptroller;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        comptroller = new Unitroller();
    }

    function testAdmin() public {
        assertEq(comptroller.admin(), root);
    }

    function testPendingAdmin() public {
        assertEq(comptroller.pendingAdmin(), address(0));
    }

    function testSetPendingAdmin() public {
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setPendingAdmin(accounts[0]);

        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), address(0));

        comptroller._setPendingAdmin(accounts[0]);

        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), accounts[0]);

        comptroller._setPendingAdmin(accounts[1]);

        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), accounts[1]);
    }

    function testAcceptAdmin() public {
        vm.expectRevert("UNAUTHORIZED");
        comptroller._acceptAdmin();

        assertEq(comptroller.admin(), root);
        assertEq(comptroller.pendingAdmin(), address(0));

        comptroller._setPendingAdmin(accounts[0]);

        vm.prank(accounts[0]);
        comptroller._acceptAdmin();

        assertEq(comptroller.admin(), accounts[0]);
        assertEq(comptroller.pendingAdmin(), address(0));
    }
}
