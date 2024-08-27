pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/Unitroller.sol";
import "../../src/Comptroller.sol";
import "../../src/PriceOracle.sol";

contract UnitrollerTest is Test {
    Unitroller unitroller;
    ComptrollerG1 brains;
    PriceOracle oracle;
    address root;
    address[] accounts;

    function setUp() public {
        root = address(this);
        accounts = new address[](10);
        for (uint i = 0; i < accounts.length; i++) {
            accounts[i] = address(uint160(uint(keccak256(abi.encodePacked(i)))));
        }
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
        vm.expectRevert("revert only unitroller admin can change brains");
        unitroller._setPendingImplementation(address(brains));

        unitroller._setPendingImplementation(address(brains));
        assertEq(unitroller.pendingComptrollerImplementation(), address(brains));
    }

    function testAcceptImplementation() public {
        unitroller._setPendingImplementation(address(brains));
        brains._become(address(unitroller), address(oracle), 0.051e18, 10, false);
        assertEq(unitroller.comptrollerImplementation(), address(brains));
        assertEq(unitroller.pendingComptrollerImplementation(), address(0));
    }

    function testFallbackDelegatesToBrains() public {
        EchoTypesComptroller troll = new EchoTypesComptroller();
        unitroller._setPendingImplementation(address(troll));
        troll.becomeBrains(payable(address(unitroller)));
        troll = EchoTypesComptroller(payable(address(unitroller)));

        vm.expectRevert("revert gotcha sucka");
        troll.reverty();

        assertEq(troll.addresses(address(troll)), address(troll));
        assertEq(troll.stringy("yeet"), "yeet");
        assertEq(troll.booly(true), true);
        uint[] memory list = new uint[](3);
        list[0] = 1;
        list[1] = 2;
        list[2] = 3;
        uint[] memory result = troll.listOInts(list);
        assertEq(result.length, 3);
        assertEq(result[0], 1);
        assertEq(result[1], 2);
        assertEq(result[2], 3);
    }
}
