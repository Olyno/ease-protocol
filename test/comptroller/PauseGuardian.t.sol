pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";

contract PauseGuardianTest is Test {
    Comptroller comptroller;
    CToken cToken;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = Compound.getAccounts();
        comptroller = new Comptroller();
    }

    function testSetPauseGuardian() public {
        vm.prank(accounts[1]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setPauseGuardian(root);

        assertEq(comptroller.pauseGuardian(), address(0));

        comptroller._setPauseGuardian(root);

        assertEq(comptroller.pauseGuardian(), root);
    }

    function testPauseGuardian() public {
        comptroller._setPauseGuardian(accounts[1]);

        assertEq(comptroller.pauseGuardian(), accounts[1]);
    }

    function testSetPaused() public {
        cToken = Compound.makeCToken(address(comptroller), true);
        comptroller._setPauseGuardian(accounts[1]);

        vm.prank(accounts[2]);
        vm.expectRevert("only pause guardian and admin can pause");
        comptroller._setTransferPaused(true);

        vm.prank(accounts[2]);
        vm.expectRevert("only pause guardian and admin can pause");
        comptroller._setSeizePaused(true);

        vm.prank(accounts[1]);
        comptroller._setTransferPaused(true);
        assertEq(comptroller.transferGuardianPaused(), true);

        vm.prank(accounts[1]);
        comptroller._setSeizePaused(true);
        assertEq(comptroller.seizeGuardianPaused(), true);

        vm.prank(accounts[1]);
        vm.expectRevert("only admin can unpause");
        comptroller._setTransferPaused(false);

        vm.prank(accounts[1]);
        vm.expectRevert("only admin can unpause");
        comptroller._setSeizePaused(false);

        comptroller._setTransferPaused(false);
        assertEq(comptroller.transferGuardianPaused(), false);

        comptroller._setSeizePaused(false);
        assertEq(comptroller.seizeGuardianPaused(), false);
    }

    function testPausedMethods() public {
        cToken = Compound.makeCToken(address(comptroller), true);
        comptroller._setPauseGuardian(accounts[1]);

        vm.prank(accounts[1]);
        comptroller._setTransferPaused(true);
        vm.expectRevert("transfer is paused");
        comptroller.transferAllowed(address(1), address(2), address(3), 1);

        vm.prank(accounts[1]);
        comptroller._setSeizePaused(true);
        vm.expectRevert("seize is paused");
        comptroller.seizeAllowed(address(1), address(2), address(3), address(4), 1);

        vm.prank(accounts[1]);
        comptroller._setMintPaused(address(cToken), true);
        vm.expectRevert("mint is paused");
        comptroller.mintAllowed(address(cToken), address(2), 1);

        vm.prank(accounts[1]);
        comptroller._setBorrowPaused(address(cToken), true);
        vm.expectRevert("borrow is paused");
        comptroller.borrowAllowed(address(cToken), address(2), 1);
    }
}
