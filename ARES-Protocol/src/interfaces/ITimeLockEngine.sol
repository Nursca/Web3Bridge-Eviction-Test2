// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

interface ITimeLockEngine {
    
    struct QueueEntry {
        uint256 proposalId;
        bytes32 commitmentHash;
        uint256 eta;
        uint256 queuedAt;
        bool executed;
    }

    event ProposalQueued(uint256 indexed proposalId, bytes32 commitmentHash, uint256 earliestTimestamp);

    event ProposalExecuted(uint256 indexed proposalId, address indexed executor, address indexed target, uint256 value);

    event ProposalDequeued(uint256 indexed proposalId, address indexed removedBy);

    function queue(uint256 proposalId, address target, bytes calldata callData, uint256 value, uint8 actionType) external returns (uint256 eta);

    function execute( uint256 proposalId, address target, bytes calldata callData,  uint256 value) external;

    function dequeue(uint256 proposalId) external;

    function getQueueEntry(uint256 proposalId) external view returns (QueueEntry memory entry);

    function isQueued(uint256 proposalId) external view returns (bool queued);

    function isExecutable(uint256 proposalId) external view returns (bool ready);

    function getDelay(uint8 actionType) external view returns (uint256 delay);
}