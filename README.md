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
