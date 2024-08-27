pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Comptroller.sol";
import "../../src/CToken.sol";

contract PauseGuardianTest is Test {
    Comptroller comptroller;
    CToken cToken;
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

    function testSetPauseGuardian() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        assertEq(comptroller.pauseGuardian(), pauseGuardian);
    }

    function testSetPauseGuardianByNonAdmin() public {
        address pauseGuardian = accounts[1];
        vm.prank(accounts[0]);
        vm.expectRevert("UNAUTHORIZED");
        comptroller._setPauseGuardian(pauseGuardian);
    }

    function testPauseGuardianCanPause() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setTransferPaused(true);
        assertEq(comptroller.transferGuardianPaused(), true);
    }

    function testPauseGuardianCannotUnpause() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setTransferPaused(true);
        vm.prank(pauseGuardian);
        vm.expectRevert("only admin can unpause");
        comptroller._setTransferPaused(false);
    }

    function testAdminCanUnpause() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setTransferPaused(true);
        comptroller._setTransferPaused(false);
        assertEq(comptroller.transferGuardianPaused(), false);
    }

    function testPauseGuardianCanPauseMarket() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setMintPaused(address(cToken), true);
        assertEq(comptroller.mintGuardianPaused(address(cToken)), true);
    }

    function testPauseGuardianCannotUnpauseMarket() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setMintPaused(address(cToken), true);
        vm.prank(pauseGuardian);
        vm.expectRevert("only admin can unpause");
        comptroller._setMintPaused(address(cToken), false);
    }

    function testAdminCanUnpauseMarket() public {
        address pauseGuardian = accounts[1];
        comptroller._setPauseGuardian(pauseGuardian);
        vm.prank(pauseGuardian);
        comptroller._setMintPaused(address(cToken), true);
        comptroller._setMintPaused(address(cToken), false);
        assertEq(comptroller.mintGuardianPaused(address(cToken)), false);
    }
}
