pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Unitroller.sol";
import "../../contracts/ComptrollerG1.sol";
import "../../contracts/PriceOracle.sol";

contract UnitrollerTest is Test {
    Unitroller unitroller;
    ComptrollerG1 brains;
    PriceOracle oracle;
    address root;
    address[] accounts;

    function setUp() public {
        (root, accounts) = getAccounts();
        oracle = new PriceOracle();
        brains = new ComptrollerG1();
        unitroller = new Unitroller();
    }

    function testConstructor() public {
        assertEq(unitroller.admin(), root);
        assertEq(unitroller.pendingAdmin(), address(0));
        assertEq(unitroller.pendingComptrollerImplementation(), address(0));
        assertEq(unitroller.comptrollerImplementation(), address(0));
    }

    function testSetPendingImplementation() public {
        vm.prank(accounts[1]);
        vm.expectRevert("UNAUTHORIZED");
        unitroller._setPendingImplementation(address(brains));

        assertEq(unitroller.pendingComptrollerImplementation(), address(0));

        unitroller._setPendingImplementation(address(brains));

        assertEq(unitroller.pendingComptrollerImplementation(), address(brains));

        vm.expectEmit(true, true, true, true);
        emit NewPendingImplementation(address(0), address(brains));
        unitroller._setPendingImplementation(address(brains));
    }

    function testAcceptImplementation() public {
        unitroller._setPendingImplementation(address(unitroller));
        vm.expectRevert("UNAUTHORIZED");
        unitroller._acceptImplementation();

        assertEq(unitroller.comptrollerImplementation(), address(0));

        unitroller._setPendingImplementation(address(brains));
        brains._become(address(unitroller), address(oracle), 0.051e18, 10, false);

        assertEq(unitroller.comptrollerImplementation(), address(brains));
        assertEq(unitroller.pendingComptrollerImplementation(), address(0));
    }

    function testFallbackDelegatesToBrains() public {
        EchoTypesComptroller troll = new EchoTypesComptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(troll));
        troll.becomeBrains(address(unitroller));
        troll = EchoTypesComptroller(address(unitroller));

        vm.expectRevert("revert gotcha sucka");
        troll.reverty();

        assertEq(troll.addresses(address(troll)), address(troll));
        assertEq(troll.stringy("yeet"), "yeet");
        assertEq(troll.booly(true), true);
        uint256[] memory list = new uint256[](3);
        list[0] = 1;
        list[1] = 2;
        list[2] = 3;
        assertEq(troll.listOInts(list), list);
    }
}
