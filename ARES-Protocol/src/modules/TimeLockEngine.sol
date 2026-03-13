// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/ITimeLockEngine.sol";
import "../interfaces/IProposalEngine.sol";
import "./GovernanceGuard.sol";

contract TimeLockEngine is ITimeLockEngine, GovernanceGuard {

    address public proposalEngine;
    uint256 public constant GRACE_PERIOD = 7 days;
    mapping(uint256 => QueueEntry) private queueEntries;
    mapping(uint8 => uint256) private actionDelay;

    bool private _entered;

    event DelaySet(uint8 indexed actionType, uint256 delay);

    modifier onlyProposalEngine() {
        require(msg.sender == proposalEngine, "TimeLockEngine: caller not proposal engine");
        _;
    }

    modifier nonReentrant() {
        require(!_entered, "TimeLockEngine: reentrancy");
        _entered = true;
        _;
        _entered = false;
    }

    constructor(address[] memory initialGovernors, uint256 transferDelay, uint256 callDelay) {
        _initializeGovernance(initialGovernors);
        actionDelay[uint8(IProposalEngine.ActionType.TRANSFER)] = transferDelay;
        actionDelay[uint8(IProposalEngine.ActionType.CALL)] = callDelay;
    }

    function setProposalEngine(address _proposalEngine) external onlyGovernor {
        require(_proposalEngine != address(0), "TimeLockEngine: zero proposal engine");
        proposalEngine = _proposalEngine;
    }

    function setDelay(uint8 actionType, uint256 delay) external onlyGovernor {
        actionDelay[actionType] = delay;
        emit DelaySet(actionType, delay);
    }

    function queue(uint256 proposalId, address target, bytes calldata callData, uint256 value, uint8 actionType)
        external
        override
        onlyProposalEngine
        returns (uint256 eta)
    {
        require (proposalEngine != address(0), "not initialized");
        require(target != address(0), "TimeLockEngine: invalid target");
        QueueEntry storage entry = queueEntries[proposalId];
        require(entry.queuedAt == 0, "TimeLockEngine: already queued");

        eta = block.timestamp + getDelay(actionType);

        entry.proposalId = proposalId;
        entry.commitmentHash = keccak256(abi.encode(proposalId, target, callData, value, actionType));
        entry.eta = eta;
        entry.queuedAt = block.timestamp;
        entry.executed = false;
        entry.actionType = actionType;

        emit ProposalQueued(proposalId, entry.commitmentHash, eta);
    }

    function execute(uint256 proposalId, address target, bytes calldata callData, uint256 value)
        external
        override
        onlyProposalEngine
        nonReentrant
    {
        QueueEntry storage entry = queueEntries[proposalId];
        require(entry.queuedAt != 0, "TimeLockEngine: not queued");
        require(!entry.executed, "TimeLockEngine: already executed");
        require(block.timestamp >= entry.eta, "TimeLockEngine: not ready");
        require(block.timestamp <= entry.eta + GRACE_PERIOD, "not ready");

        bytes32 expected = keccak256(abi.encode(proposalId, target, callData, value, entry.actionType));
        // allow either action type in hash to give compatibility to both transfer and call semantics
        require(entry.commitmentHash == expected, "commitment mismatch");

        entry.executed = true;
        IProposalEngine(proposalEngine).markExecuted(proposalId);

        (bool success, bytes memory data) = target.call{value: value}(callData);
        
        require(success, string(data));

        emit ProposalExecuted(proposalId, msg.sender, target, value);
    }

    function dequeue(uint256 proposalId) external override onlyProposalEngine {
        QueueEntry storage entry = queueEntries[proposalId];
        require(entry.queuedAt != 0, "TimeLockEngine: not queued");
        require(!entry.executed, "TimeLockEngine: already executed");

        delete queueEntries[proposalId];
        emit ProposalDequeued(proposalId, msg.sender);
    }

    function getQueueEntry(uint256 proposalId) external view override returns (QueueEntry memory) {
        return queueEntries[proposalId];
    }

    function isQueued(uint256 proposalId) external view override returns (bool queued) {
        queued = queueEntries[proposalId].queuedAt != 0 && !queueEntries[proposalId].executed;
    }

    function isExecutable(uint256 proposalId) external view override returns (bool ready) {
        QueueEntry storage entry = queueEntries[proposalId];
        ready = entry.queuedAt != 0 && !entry.executed 
        && block.timestamp >= entry.eta
        && block.timestamp <= entry.eta + GRACE_PERIOD;
    }

    function getDelay(uint8 actionType) public view override returns (uint256 delay) {
        delay = actionDelay[actionType];
    }
}
