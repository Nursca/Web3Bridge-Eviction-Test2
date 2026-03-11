# ARES Protocol Architecture

## System Architeture
Ares Protocol system architeture is a secure treasury execution system that allows protocol governance.
The system ia intentionally modular. 
This reduces risk of potential failures and allows each feature to be audited or upgraded without affecting the entire architecture.

## Module separation
Each Module contributes to the proposal lifecycle, cryptographic approval, time delay mechanism, reward distribution and defense mechanism

### Modules
* **ProposalEngine** - manages the proposal lifecycle and state transitions
* **SignatureVerifier** - validates ECDSA + EIP-712 authorizations with a nonce per signer
* **TimeLockEngine** - enforces execution delays using a queue-based system with non-reentrant execution
* **GovernaceGuard** - base guard layer implementing a multi-governor access control list (ACL)
* **RewardDistributior - handles Merkle-based reward claims with bitmap tracking

### Core Contract
* **AresTreaury** - the on-chain asset vault, executable only within the timelock context

### Supporting Libraries
* **Signature** - constructs EIP-712 domain separators and payload hashes
* **Merkle** - utilities for leaf generation, hash pairing, and proof verification

## Visual Flow

<img width="2543" height="998" alt="Untitled-2026-03-05-2115" src="https://github.com/user-attachments/assets/2c6a2c91-27ca-4f1b-b921-3a743ebce9cb" />
