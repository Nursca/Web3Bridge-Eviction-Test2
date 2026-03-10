// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IProposalEngine {
    enum ProposalStatus {
        NONE, // Proposal doesn't exist
        DRAFT, // 1 - Proposal created and awaiting signatures
        COMMIT, // 2 - Proposal in signature collection phase
        QUEUED, // 3 - Proposal quorum met, entered timelock queue
        READY, // 4 - Proposal timelock executed
        EXECUTED, // 5 - Proposal successfully executed
        CANCELLED // 6 - Proposal cancelled by proposer/governance
    }

    enum ActionType {
        TRANSFER, 
        CALL
    }

    struct Proposal {
        uint256 id;
        address proposer;
        ActionType actionType;
        address target;
        bytes32 payloadHash;
        uint256 value;
        uint256 bond;
        uint256 createdAt;
        uint256 snapshotBlock;
        ProposalStatus status;
    }

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ActionType actionType,
        address indexed target,
        bytes callData,
        uint256 value,
        uint256 bond, 
        uint256 snapshotBlock
    );

    event ProposalStatusChanged(
        uint256 indexed proposalId,
        ProposalStatus oldStatus,
        ProposalStatus newStatus
    );

    event ProposalCancelled(
        uint256 indexed proposalId,
        address indexed cancelledBy,
        bool bondSlashed
    );

    function propose(ActionType actionType, address target, bytes calldata callData, uint256 value) external payable returns (uint256 proposalId);

    function cancel(uint256 proposalId) external;

    function moveToCommit(uint256 proposalId) external;

    function moveToQueued(uint256 proposalId) external;

    function moveToReady(uint256 proposalId) external;

    function markExecuted(uint256 proposalId) external;

    function getProposal(uint256 proposalId) external view returns (Proposal memory proposal);

    function getStatus(uint256 proposalId) external view returns (ProposalStatus status);

    function activeProposalCount(address proposer) external view returns (uint256 count);

    function minimumBond(ActionType actionType, uint256 value) external view returns (uint256 bond);
}