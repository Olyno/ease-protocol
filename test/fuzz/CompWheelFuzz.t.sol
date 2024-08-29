pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Comptroller.sol";
import "../../contracts/CToken.sol";
import "../../contracts/Token.sol";

contract CompWheelFuzzTest is Test {
    using SafeMath for uint256;

    uint256 constant RUN_COUNT = 20;
    uint256 constant NUM_EVENTS = 50;
    uint256 constant PRECISION_DECIMALS = 15;

    struct Globals {
        uint256 blockNumber;
        address[] accounts;
    }

    struct State {
        uint256 accrualBlockNumber;
        uint256 borrowIndex;
        uint256 totalCash;
        uint256 totalSupply;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 reserveFactor;
        mapping(address => uint256) balances;
        mapping(address => uint256) borrowBalances;
        mapping(address => uint256) borrowIndexSnapshots;
        uint256 compSupplySpeed;
        uint256 compSupplyIndex;
        mapping(address => uint256) compSupplyIndexSnapshots;
        uint256 compSupplyIndexUpdatedBlock;
        uint256 compBorrowSpeed;
        uint256 compBorrowIndex;
        mapping(address => uint256) compBorrowIndexSnapshots;
        uint256 compBorrowIndexUpdatedBlock;
        mapping(address => uint256) compAccruedWithCrank;
        mapping(address => uint256) compAccruedWithIndex;
        uint256 activeBorrowBlocks;
        uint256 activeSupplyBlocks;
    }

    function rand(uint256 x) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % x;
    }

    function range(uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            arr[i] = i;
        }
        return arr;
    }

    function get(uint256 src) internal pure returns (uint256) {
        return src;
    }

    function isPositive(uint256 src) internal pure returns (bool) {
        return src > 0;
    }

    function almostEqual(uint256 expected, uint256 actual) internal pure returns (bool) {
        return expected == actual;
    }

    function deepCopy(State memory src) internal pure returns (State memory) {
        State memory copy;
        copy.accrualBlockNumber = src.accrualBlockNumber;
        copy.borrowIndex = src.borrowIndex;
        copy.totalCash = src.totalCash;
        copy.totalSupply = src.totalSupply;
        copy.totalBorrows = src.totalBorrows;
        copy.totalReserves = src.totalReserves;
        copy.reserveFactor = src.reserveFactor;
        copy.compSupplySpeed = src.compSupplySpeed;
        copy.compSupplyIndex = src.compSupplyIndex;
        copy.compSupplyIndexUpdatedBlock = src.compSupplyIndexUpdatedBlock;
        copy.compBorrowSpeed = src.compBorrowSpeed;
        copy.compBorrowIndex = src.compBorrowIndex;
        copy.compBorrowIndexUpdatedBlock = src.compBorrowIndexUpdatedBlock;
        copy.activeBorrowBlocks = src.activeBorrowBlocks;
        copy.activeSupplyBlocks = src.activeSupplyBlocks;

        for (uint256 i = 0; i < src.accounts.length; i++) {
            address account = src.accounts[i];
            copy.balances[account] = src.balances[account];
            copy.borrowBalances[account] = src.borrowBalances[account];
            copy.borrowIndexSnapshots[account] = src.borrowIndexSnapshots[account];
            copy.compSupplyIndexSnapshots[account] = src.compSupplyIndexSnapshots[account];
            copy.compBorrowIndexSnapshots[account] = src.compBorrowIndexSnapshots[account];
            copy.compAccruedWithCrank[account] = src.compAccruedWithCrank[account];
            copy.compAccruedWithIndex[account] = src.compAccruedWithIndex[account];
        }

        return copy;
    }

    function initialState(Globals memory globals) internal pure returns (State memory) {
        State memory state;
        state.accrualBlockNumber = globals.blockNumber;
        state.borrowIndex = 1;
        state.totalCash = 0;
        state.totalSupply = 0;
        state.totalBorrows = 0;
        state.totalReserves = 0;
        state.reserveFactor = 0.05;
        state.compSupplySpeed = 1;
        state.compSupplyIndex = 1;
        state.compSupplyIndexUpdatedBlock = globals.blockNumber;
        state.compBorrowSpeed = 1;
        state.compBorrowIndex = 1;
        state.compBorrowIndexUpdatedBlock = globals.blockNumber;
        state.activeBorrowBlocks = 0;
        state.activeSupplyBlocks = 0;

        for (uint256 i = 0; i < globals.accounts.length; i++) {
            address account = globals.accounts[i];
            state.balances[account] = 0;
            state.borrowBalances[account] = 0;
            state.borrowIndexSnapshots[account] = 0;
            state.compSupplyIndexSnapshots[account] = 0;
            state.compBorrowIndexSnapshots[account] = 0;
            state.compAccruedWithCrank[account] = 0;
            state.compAccruedWithIndex[account] = 0;
        }

        return state;
    }

    function getExchangeRate(State memory state) internal pure returns (uint256) {
        if (isPositive(state.totalSupply)) {
            return state.totalCash.add(state.totalBorrows).sub(state.totalReserves).div(state.totalSupply);
        } else {
            return 1;
        }
    }

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) internal pure returns (uint256) {
        uint256 denom = cash.add(borrows).sub(reserves);
        if (denom == 0) {
            return 0;
        } else if (denom < 0) {
            revert("Borrow Rate failure");
        } else {
            uint256 util = borrows.div(denom);
            return util.mul(0.001);
        }
    }

    function trueUpComp(Globals memory globals, State memory state) internal pure returns (State memory) {
        state = accrueInterest(globals, state);

        for (uint256 i = 0; i < globals.accounts.length; i++) {
            address account = globals.accounts[i];
            state = supplierFlywheelByIndex(globals, state, account);
            state = borrowerFlywheelByIndex(globals, state, account);
        }

        return state;
    }

    function flywheelByCrank(State memory state, uint256 deltaBlocks, uint256 borrowIndexNew, uint256 borrowIndexPrev) internal pure returns (State memory) {
        for (uint256 i = 0; i < state.accounts.length; i++) {
            address account = state.accounts[i];
            if (isPositive(state.totalSupply)) {
                state.compAccruedWithCrank[account] = get(state.compAccruedWithCrank[account]).add(
                    deltaBlocks.mul(state.compSupplySpeed).mul(state.balances[account]).div(state.totalSupply)
                );
            }

            if (isPositive(state.totalBorrows)) {
                uint256 truedUpBorrowBalance = getAccruedBorrowBalance(state, account);
                state.compAccruedWithCrank[account] = get(state.compAccruedWithCrank[account]).add(
                    deltaBlocks.mul(state.compBorrowSpeed).mul(truedUpBorrowBalance).div(state.totalBorrows)
                );
            }
        }

        return state;
    }

    function borrowerFlywheelByIndex(Globals memory globals, State memory state, address account) internal pure returns (State memory) {
        uint256 deltaBlocks = globals.blockNumber.sub(state.compBorrowIndexUpdatedBlock);
        if (isPositive(state.totalBorrows)) {
            uint256 scaledTotalBorrows = state.totalBorrows.div(state.borrowIndex);
            state.compBorrowIndex = state.compBorrowIndex.add(
                state.compBorrowSpeed.mul(deltaBlocks).div(scaledTotalBorrows)
            );
        }

        uint256 indexSnapshot = state.compBorrowIndexSnapshots[account];
        if (indexSnapshot != 0 && state.compBorrowIndex > indexSnapshot && state.borrowBalances[account] != 0) {
            uint256 borrowBalanceNew = state.borrowBalances[account].mul(state.borrowIndex).div(state.borrowIndexSnapshots[account]);
            state.compAccruedWithIndex[account] = get(state.compAccruedWithIndex[account]).add(
                borrowBalanceNew.div(state.borrowIndex).mul(state.compBorrowIndex.sub(indexSnapshot))
            );
        }

        state.compBorrowIndexUpdatedBlock = globals.blockNumber;
        state.compBorrowIndexSnapshots[account] = state.compBorrowIndex;

        return state;
    }

    function supplierFlywheelByIndex(Globals memory globals, State memory state, address account) internal pure returns (State memory) {
        uint256 deltaBlocks = globals.blockNumber.sub(state.compSupplyIndexUpdatedBlock);
        if (isPositive(state.totalSupply)) {
            state.compSupplyIndex = state.compSupplyIndex.add(
                state.compSupplySpeed.mul(deltaBlocks).div(state.totalSupply)
            );
        }

        uint256 indexSnapshot = state.compSupplyIndexSnapshots[account];
        if (indexSnapshot != 0) {
            state.compAccruedWithIndex[account] = get(state.compAccruedWithIndex[account]).add(
                state.balances[account].mul(state.compSupplyIndex.sub(indexSnapshot))
            );
        }

        state.compSupplyIndexUpdatedBlock = globals.blockNumber;
        state.compSupplyIndexSnapshots[account] = state.compSupplyIndex;

        return state;
    }

    function accrueActiveBlocks(State memory state, uint256 deltaBlocks) internal pure returns (State memory) {
        if (isPositive(state.totalSupply)) {
            state.activeSupplyBlocks = state.activeSupplyBlocks.add(deltaBlocks);
        }

        if (isPositive(state.totalBorrows)) {
            state.activeBorrowBlocks = state.activeBorrowBlocks.add(deltaBlocks);
        }

        return state;
    }

    function getAccruedBorrowBalance(State memory state, address account) internal pure returns (uint256) {
        uint256 prevBorrowBalance = state.borrowBalances[account];
        uint256 checkpointBorrowIndex = state.borrowIndexSnapshots[account];
        if (prevBorrowBalance != 0 && checkpointBorrowIndex != 0) {
            return prevBorrowBalance.mul(state.borrowIndex).div(checkpointBorrowIndex);
        } else {
            return 0;
        }
    }

    function accrueInterest(Globals memory globals, State memory state) internal pure returns (State memory) {
        uint256 deltaBlocks = globals.blockNumber.sub(state.accrualBlockNumber);
        state = accrueActiveBlocks(state, deltaBlocks);

        uint256 borrowRate = getBorrowRate(state.totalCash, state.totalBorrows, state.totalReserves);
        uint256 simpleInterestFactor = deltaBlocks.mul(borrowRate);
        uint256 borrowIndexNew = state.borrowIndex.mul(simpleInterestFactor.add(1));
        uint256 interestAccumulated = state.totalBorrows.mul(simpleInterestFactor);
        uint256 totalBorrowsNew = state.totalBorrows.add(interestAccumulated);
        uint256 totalReservesNew = state.totalReserves.add(interestAccumulated).mul(state.reserveFactor);

        state = flywheelByCrank(state, deltaBlocks, borrowIndexNew, state.borrowIndex);

        state.accrualBlockNumber = globals.blockNumber;
        state.borrowIndex = borrowIndexNew;
        state.totalBorrows = totalBorrowsNew;
        state.totalReserves = totalReservesNew;

        return state;
    }

    function mine(Globals memory globals, State memory state, uint256 mineAmount) internal pure returns (State memory) {
        return state;
    }

    function gift(Globals memory globals, State memory state, uint256 amount) internal pure returns (State memory) {
        state.totalCash = state.totalCash.add(amount);
        return state;
    }

    function borrow(Globals memory globals, State memory state, address account, uint256 amount) internal pure returns (State memory) {
        state = accrueInterest(globals, state);
        state = borrowerFlywheelByIndex(globals, state, account);

        uint256 newTotalCash = state.totalCash.sub(amount);
        require(isPositive(newTotalCash.add(state.totalReserves)), "Attempted to borrow more than total cash");

        uint256 newBorrowBalance = getAccruedBorrowBalance(state, account).add(amount);
        require(get(state.balances[account]).mul(getExchangeRate(state)) > newBorrowBalance, "Borrower undercollateralized");

        state.totalBorrows = state.totalBorrows.add(amount);
        state.totalCash = newTotalCash;
        state.borrowBalances[account] = newBorrowBalance;
        state.borrowIndexSnapshots[account] = state.borrowIndex;

        return state;
    }

    function repayBorrow(Globals memory globals, State memory state, address account, uint256 amount) internal pure returns (State memory) {
        state = accrueInterest(globals, state);
        state = borrowerFlywheelByIndex(globals, state, account);

        uint256 accruedBorrowBalance = getAccruedBorrowBalance(state, account);
        require(isPositive(accruedBorrowBalance), "No active borrow");

        if (amount > accruedBorrowBalance) {
            delete state.borrowIndexSnapshots[account];
            delete state.borrowBalances[account];
            state.totalBorrows = state.totalBorrows.sub(accruedBorrowBalance);
        } else {
            state.borrowIndexSnapshots[account] = state.borrowIndex;
            state.borrowBalances[account] = accruedBorrowBalance.sub(amount);
            state.totalBorrows = state.totalBorrows.sub(amount);
        }

        state.totalCash = state.totalCash.add(amount.min(accruedBorrowBalance));

        return state;
    }

    function mint(Globals memory globals, State memory state, address account, uint256 amount) internal pure returns (State memory) {
        state = accrueInterest(globals, state);
        state = supplierFlywheelByIndex(globals, state, account);

        uint256 balance = get(state.balances[account]);
        uint256 exchangeRate = getExchangeRate(state);
        uint256 tokens = amount.div(exchangeRate);

        state.totalCash = state.totalCash.add(amount);
        state.totalSupply = state.totalSupply.add(tokens);
        state.balances[account] = balance.add(tokens);

        return state;
    }

    function redeem(Globals memory globals, State memory state, address account, uint256 tokens) internal pure returns (State memory) {
        state = accrueInterest(globals, state);
        state = supplierFlywheelByIndex(globals, state, account);

        uint256 balance = get(state.balances[account]);
        require(balance > tokens, "Redeem fails for insufficient balance");

        uint256 exchangeRate = getExchangeRate(state);
        uint256 amount = tokens.mul(exchangeRate);

        state.totalCash = state.totalCash.sub(amount);
        state.totalSupply = state.totalSupply.sub(tokens);
        state.balances[account] = balance.sub(tokens);

        return state;
    }

    function generateGlobals() internal pure returns (Globals memory) {
        Globals memory globals;
        globals.blockNumber = 1000;
        globals.accounts = new address[](3);
        globals.accounts[0] = address(0x1);
        globals.accounts[1] = address(0x2);
        globals.accounts[2] = address(0x3);
        return globals;
    }

    function crankCorrectnessInvariant(Globals memory globals, State memory state, uint256[] memory events) internal pure {
        uint256 expected = state.activeSupplyBlocks.mul(state.compSupplySpeed).add(state.activeBorrowBlocks.mul(state.compBorrowSpeed));
        uint256 actual = 0;

        for (uint256 i = 0; i < globals.accounts.length; i++) {
            actual = actual.add(state.compAccruedWithCrank[globals.accounts[i]]);
        }

        require(almostEqual(expected, actual), "crank method distributed comp inaccurately");
    }

    function indexCorrectnessInvariant(Globals memory globals, State memory state, uint256[] memory events) internal pure {
        for (uint256 i = 0; i < globals.accounts.length; i++) {
            address account = globals.accounts[i];
            require(almostEqual(state.compAccruedWithCrank[account], state.compAccruedWithIndex[account]), "crank method does not match index method");
        }
    }

    function testInvariants(Globals memory globals, State memory state, uint256[] memory events) internal pure {
        crankCorrectnessInvariant(globals, state, events);
        indexCorrectnessInvariant(globals, state, events);
    }

    function randActor() internal view returns (uint256) {
        return rand(6);
    }

    function executeAction(Globals memory globals, State memory state, uint256 eventIndex, uint256 i) internal pure returns (State memory) {
        if (eventIndex == 0) {
            return mine(globals, state, rand(100));
        } else if (eventIndex == 1) {
            return mint(globals, state, globals.accounts[rand(globals.accounts.length)], rand(1000));
        } else if (eventIndex == 2) {
            return redeem(globals, state, globals.accounts[rand(globals.accounts.length)], rand(1000));
        } else if (eventIndex == 3) {
            return gift(globals, state, rand(1000));
        } else if (eventIndex == 4) {
            return borrow(globals, state, globals.accounts[rand(globals.accounts.length)], rand(1000));
        } else if (eventIndex == 5) {
            return repayBorrow(globals, state, globals.accounts[rand(globals.accounts.length)], rand(1000));
        } else {
            revert("Invalid event index");
        }
    }

    function runEvents(Globals memory globals, State memory initState, uint256[] memory events) internal pure returns (State memory) {
        State memory state = initState;

        for (uint256 i = 0; i < events.length; i++) {
            state = executeAction(globals, state, events[i], i);
        }

        return trueUpComp(globals, state);
    }

    function generateEvent(Globals memory globals) internal view returns (uint256) {
        return randActor();
    }

    function generateEvents(Globals memory globals, uint256 count) internal view returns (uint256[] memory) {
        uint256[] memory events = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            events[i] = generateEvent(globals);
        }

        return events;
    }

    function go() internal view {
        Globals memory globals = generateGlobals();
        State memory initState = initialState(globals);
        uint256[] memory events = generateEvents(globals, NUM_EVENTS);
        State memory state = runEvents(globals, initState, events);

        testInvariants(globals, state, events);
    }

    function testCompWheelFuzz() public {
        for (uint256 i = 0; i < RUN_COUNT; i++) {
            go();
        }
    }
}
