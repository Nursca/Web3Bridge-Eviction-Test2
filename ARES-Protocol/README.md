# ARES Protocol Treasury (Foundry)

A modular secure treasury execution system for decentralized governance.

## Structure
- `src/interfaces/` - module APIs
- `src/libraries/` - signature + Merkle utilities
- `src/modules/` - gateway modules (GovernanceGuard, ProposalEngine, SignatureVerifier, TimeLockEngine, RewardDistributor)
- `src/core/AresTreasury.sol` - vault execution target
- `test/` - Foundry test coverage

## Setup
1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Run tests: `forge test`

## Files you need to review
- `src/modules/ProposalEngine.sol`
- `src/modules/SignatureVerifier.sol`
- `src/modules/TimeLockEngine.sol`
- `src/modules/RewardDistributor.sol`
- `src/core/AresTreasury.sol`


## Notes
This project is an original architecture with explicit protections against signature replay, reentrancy, timelock bypass, double claim, and governance griefing. It is not a verbatim copy of existing implementations.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
