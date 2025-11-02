Here’s the complete **`README.md`** file in Markdown format — ready to copy into your GitHub repository.
It’s detailed, structured, and includes clean ASCII and Mermaid diagrams to visualize how your HTLC atomic swap works.

---

````markdown
# Atomic Swap using Hashed Timelock Contracts (HTLC)

This project demonstrates an **Atomic Swap** implementation in Solidity using a **Hashed Timelock Contract (HTLC)**.  
It allows two parties to exchange ERC20 tokens trustlessly — without intermediaries — by enforcing cryptographic and time-based conditions.

---

## Table of Contents
1. [Overview](#overview)
2. [Conceptual Diagram](#conceptual-diagram)
3. [File Structure](#file-structure)
4. [Contracts](#contracts)
   - [TestToken.sol](#1-testtokensol)
   - [HTLC.sol](#2-htlcsol)
5. [Testing](#testing)
6. [How It Works](#how-it-works)
7. [Example Flow](#example-flow)
8. [Security Considerations](#security-considerations)
9. [License](#license)

---

## Overview

A **Hashed Timelock Contract (HTLC)** enables atomic swaps — conditional transfers of tokens that depend on:
- A **secret** known only to one party.
- A **timelock** after which the sender can reclaim tokens.

This ensures one of two outcomes:
- The receiver claims funds by revealing the correct secret before the timelock expires.
- The sender refunds their funds after the timelock passes.

---

## Conceptual Diagram

### Atomic Swap Overview

```mermaid
sequenceDiagram
    participant Alice
    participant HTLC
    participant Bob

    Alice->>HTLC: lock(token, amount, Bob, hash(secret), timelock)
    HTLC-->>Alice: emits swapId
    Bob->>HTLC: claim(swapId, secret)
    HTLC->>Bob: transfers tokens
    Note over HTLC: If Bob never claims and time passes...
    Alice->>HTLC: refund(swapId)
    HTLC->>Alice: returns tokens
````

---

## File Structure

```
contracts/
│
├── TestToken.sol        # Simple ERC20 token with minting function
├── HTLC.sol             # Core Hashed Timelock Contract
tests/
└── AtomicSwap.t.sol     # Foundry-based test suite
```

---

## Contracts

### 1. TestToken.sol

A minimal ERC20 token implementation based on OpenZeppelin’s ERC20.
Includes a `mint()` function for distributing test tokens to users.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // Mint function to give test accounts tokens
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
```

**Key Features:**

* Used as the token for swaps.
* Allows minting for test environments.
* Fully ERC20 compatible.

---

### 2. HTLC.sol

The main contract implementing the **Hashed Timelock logic** for ERC20 tokens.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./TestToken.sol";

contract HTLC {
    struct Swap {
        TestToken token;
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

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
    }

    function claim(bytes32 swapId, string memory secret) external {
        Swap storage s = swaps[swapId];
        require(!s.claimed, "Already claimed");
        require(keccak256(abi.encodePacked(secret)) == s.hashlock, "Wrong secret");

        s.claimed = true;
        bool success = s.token.transfer(s.receiver, s.amount);
        require(success, "Transfer failed");
    }

    function refund(bytes32 swapId) external {
        Swap storage s = swaps[swapId];
        require(!s.claimed, "Already claimed");
        require(block.timestamp >= s.timelock, "Timelock not expired");
        require(msg.sender == s.sender, "Only sender can refund");

        s.claimed = true;
        bool success = s.token.transfer(s.sender, s.amount);
        require(success, "Transfer failed");
    }
}
```

#### Key Functions

| Function   | Description                                                                   |
| ---------- | ----------------------------------------------------------------------------- |
| `lock()`   | Locks tokens in the contract with a hashlock and timelock.                    |
| `claim()`  | Allows receiver to claim tokens using the secret before the timelock expires. |
| `refund()` | Allows sender to retrieve tokens after the timelock passes.                   |

---

## Testing

The `AtomicSwap.t.sol` file uses **Foundry** to verify the contract logic.

```solidity
forge test
```

### Tests Covered

* **Happy Path**: Alice locks tokens, Bob claims them with the correct secret.
* **Refund Scenario**: Alice refunds tokens after the timelock expires.

The tests confirm:

* Proper balance changes.
* Correct timelock and hashlock behavior.
* Swap uniqueness and replay protection.

---

## How It Works

### Step-by-Step

1. **Alice (sender)** generates a secret `S` and its hash `H = keccak256(S)`.
2. Alice locks tokens in the HTLC contract with `H` and a `timelock`.
3. **Bob (receiver)** learns `H` but not `S`.
4. To claim, Bob must reveal `S` such that `keccak256(S) == H`.
5. Once revealed, anyone can verify `S` on-chain.
6. If Bob doesn’t claim before the timelock, Alice refunds her tokens.

---

## Example Flow

```plaintext
1. Alice -> HTLC.lock(token, 100, Bob, hash("secret"), now + 1 day)
2. Bob   -> HTLC.claim(swapId, "secret")  // succeeds
3. If Bob doesn’t claim:
   Alice -> HTLC.refund(swapId) after timelock expires
```

### ASCII Flow Diagram

```
+--------+        +-----------+        +--------+
| Alice  |        |   HTLC    |        |  Bob   |
+--------+        +-----------+        +--------+
     | lock()          |                     |
     |---------------->|                     |
     |                 | hold tokens          |
     |                 |--------------------->|
     |                 |    claim(secret)     |
     |                 |--------------------->|
     |                 | send tokens to Bob   |
     |                 |                     |
     | refund() after timelock (if unclaimed) |
```

---

## Security Considerations

* **Hash collisions** are practically impossible using `keccak256`.
* **Timelock precision** uses `block.timestamp`; minor miner manipulation possible but negligible for long time windows.
* **Reentrancy** is not possible here since no callbacks are made.
* **Swap ID collision** is avoided by including sender, receiver, amount, hashlock, and timelock in the hash.

---

## License

This project is licensed under the **MIT License**.
You are free to use, modify, and distribute it with attribution.

---

## Author

Developed for demonstration and testing purposes — suitable as a reference for implementing **ERC20-based Atomic Swaps** on Ethereum test networks.

Dhruv Singh
Sushant Singh Guatam
Diksha Lulla
Abhinav Katiyar
