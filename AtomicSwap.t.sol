// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../TestToken.sol";
import "../HTLC.sol";

contract AtomicSwapTest is Test {
    TestToken token;
    HTLC htlc;

    address alice = address(0x1);
    address bob = address(0x2);
    
    // Initial balance for all users
    uint256 constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        // Deploy token and HTLC
        token = new TestToken("TestToken", "TTK");
        htlc = new HTLC();

        // Mint enough tokens
        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);

        // Label addresses (optional)
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
    }

    function test_HappyPath() public {
        bytes32 hashlock = keccak256(abi.encodePacked("secret"));
        uint256 amount = 100 ether;
        uint256 timelock = block.timestamp + 1 days;

        // Alice approves HTLC and locks tokens (needs to be Alice's call)
        vm.startPrank(alice);
        token.approve(address(htlc), amount);
        bytes32 swapId = htlc.lock(token, amount, bob, hashlock, timelock);
        vm.stopPrank();

        // Check HTLC holds the amount
        assertEq(token.balanceOf(address(htlc)), amount, "HTLC balance incorrect after lock");

        // Bob claims (needs to be Bob's call)
        vm.prank(bob);
        htlc.claim(swapId, "secret");

        // Check final balances
        // Alice: 1000 - 100 = 900
        assertEq(token.balanceOf(alice), INITIAL_BALANCE - amount, "Alice's final balance incorrect");
        // Bob: 1000 + 100 = 1100
        assertEq(token.balanceOf(bob), INITIAL_BALANCE + amount, "Bob's final balance incorrect");
        // HTLC: 0
        assertEq(token.balanceOf(address(htlc)), 0, "HTLC balance should be zero after claim");
    }
    

    function test_Refund() public {
        bytes32 hashlock = keccak256(abi.encodePacked("secret2"));
        uint256 amount = 50 ether;
        uint256 timelock = block.timestamp + 1 days;

        // Alice approves HTLC and locks tokens (needs to be Alice's call)
        vm.startPrank(alice);
        token.approve(address(htlc), amount);
        bytes32 swapId = htlc.lock(token, amount, bob, hashlock, timelock);
        vm.stopPrank();

        // Check HTLC holds the amount
        assertEq(token.balanceOf(address(htlc)), amount, "HTLC balance incorrect after lock");

        // Move time past timelock
        vm.warp(block.timestamp + 2 days);

        // Refund by Alice (must be Alice who calls refund)
        vm.prank(alice);
        htlc.refund(swapId);

        // Check final balance: Alice should be back to 1000 ether
        assertEq(token.balanceOf(alice), INITIAL_BALANCE, "Alice's balance should be fully refunded");
        // Bob's balance should be unchanged
        assertEq(token.balanceOf(bob), INITIAL_BALANCE, "Bob's balance should be unchanged after refund");
        // HTLC: 0
        assertEq(token.balanceOf(address(htlc)), 0, "HTLC balance should be zero after refund");
    }
}
