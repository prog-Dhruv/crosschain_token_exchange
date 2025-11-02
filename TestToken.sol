// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./TestToken.sol";

contract HTLC {
    struct Swap {
        TestToken token;    // store token contract
        address sender;
        address receiver;
        uint256 amount;
        bytes32 hashlock;
        uint256 timelock;
        bool claimed;
    }

    mapping(bytes32 => Swap) public swaps;

    function lock(  
        TestToken token,
        uint256 amount,
        address receiver,
        bytes32 hashlock,
        uint256 timelock
    ) external returns (bytes32 swapId) {
        swapId = keccak256(abi.encodePacked(msg.sender, receiver, amount, hashlock, timelock));

        // Use 'sender == address(0)' to check if swapId is unused
        require(swaps[swapId].sender == address(0), "Swap exists");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        swaps[swapId] = Swap({
            token: token,
            sender: msg.sender,
            receiver: receiver,
            amount: amount,
            hashlock: hashlock,
            timelock: timelock,
            claimed: false
        });

        // The HTLC contract must be approved to spend msg.sender's tokens
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
    }

    function claim(bytes32 swapId, string memory secret) external {
        Swap storage s = swaps[swapId];
        require(!s.claimed, "Already claimed");
        
        // Correctly calculate hashlock of the secret
        require(keccak256(abi.encodePacked(secret)) == s.hashlock, "Wrong secret");

        s.claimed = true;
        // Transfer to the intended receiver
        bool success = s.token.transfer(s.receiver, s.amount);
        require(success, "Transfer failed");
    }

    function refund(bytes32 swapId) external {
        Swap storage s = swaps[swapId];
        require(!s.claimed, "Already claimed");
        require(block.timestamp >= s.timelock, "Timelock not expired");
        require(msg.sender == s.sender, "Only sender can refund");

        s.claimed = true;
        // Transfer back to the original sender
        bool success = s.token.transfer(s.sender, s.amount);
        require(success, "Transfer failed");
    }
}
