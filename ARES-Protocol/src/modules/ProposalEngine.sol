// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IProposalEngine.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/ITimeLockEngine.sol";
import "./GovernanceGuard.sol";

contract ProposalEngine is IProposalEngine, GovernanceGuard {
    ISignatureVerifier public signatureVerifier;
    ITimeLockEngine public timeLockEngine;

    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256) private _activeProposalCount;
    mapping(uint256 => bytes) private _proposalCallData;
    uint256 public proposalCount;
    uint256 public maxActiveProposals = 2;

    event ProposalCommitted(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId);
    event ProposalReady(uint256 indexed proposalId);
    event ProposalExecutedState(uint256 indexed proposalId);

    modifier onlyProposalProposer(uint256 proposalId) {
        require(proposals[proposalId].proposer == msg.sender, "ProposalEngine: not proposer");
        _;
    }

    constructor(address[] memory initialGovernors, address _signatureVerifier, address _timeLockEngine) {
        _initializeGovernance(initialGovernors);
        signatureVerifier = ISignatureVerifier(_signatureVerifier);
        timeLockEngine = ITimeLockEngine(_timeLockEngine);
    }

    function setSignatureVerifier(address _signatureVerifier) external onlyGovernor {
        require(_signatureVerifier != address(0), "ProposalEngine: zero signature verifier");
        signatureVerifier = ISignatureVerifier(_signatureVerifier);
    }

    function setTimeLockEngine(address _timeLockEngine) external onlyGovernor {
        require(_timeLockEngine != address(0), "ProposalEngine: zero timelock engine");
        timeLockEngine = ITimeLockEngine(_timeLockEngine);
    }

    function propose(ActionType actionType, address target, bytes calldata callData, uint256 value)
        external
        payable
        override
        onlyGovernor
        returns (uint256 proposalId)
    {
        require(target != address(0), "ProposalEngine: invalid target");
        require(_activeProposalCount[msg.sender] < maxActiveProposals, "ProposalEngine: too many active proposals");

        proposalId = ++proposalCount;
        bytes32 payloadHash = keccak256(callData);

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            actionType: actionType,
            target: target,
            payloadHash: payloadHash,
            value: value,
            bond: msg.value,
            createdAt: block.timestamp,
            snapshotBlock: block.number,
            status: ProposalStatus.DRAFT
        });
        _proposalCallData[proposalId] = callData;
        _activeProposalCount[msg.sender] += 1;

        emit ProposalCreated(proposalId, msg.sender, actionType, target, callData, value, msg.value, block.number);
    }

    function cancel(uint256 proposalId) external override {
        Proposal storage prop = proposals[proposalId];
        require(prop.status != ProposalStatus.CANCELLED && prop.status != ProposalStatus.EXECUTED, "ProposalEngine: invalid status");
        require(msg.sender == prop.proposer || isGovernor[msg.sender], "ProposalEngine: not authorized");

        prop.status = ProposalStatus.CANCELLED;
        if (_activeProposalCount[prop.proposer] > 0) {
            _activeProposalCount[prop.proposer] -= 1;
        }

        if (timeLockEngine.isQueued(proposalId)) {
            timeLockEngine.dequeue(proposalId);
        }
        emit ProposalCancelled(proposalId, msg.sender, prop.bond > 0);
    }

    function moveToCommit(uint256 proposalId) external override onlyProposalProposer(proposalId) {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == ProposalStatus.DRAFT, "ProposalEngine: invalid stage");
        prop.status = ProposalStatus.COMMIT;
        prop.snapshotBlock = block.number;
        emit ProposalStatusChanged(proposalId, ProposalStatus.DRAFT, ProposalStatus.COMMIT);
        emit ProposalCommitted(proposalId);
    }

    function moveToQueued(uint256 proposalId) external override {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == ProposalStatus.COMMIT, "ProposalEngine: invalid stage");

        uint256 required = signatureVerifier.getThreshold(uint8(prop.actionType));
        require(required > 0, "ProposalEngine: no threshold");
        require(signatureVerifier.signatureCount(proposalId) >= required, "ProposalEngine: insufficient signatures");

        timeLockEngine.queue(proposalId, prop.target, _proposalCallData[proposalId], prop.value, uint8(prop.actionType));

        prop.status = ProposalStatus.QUEUED;
        emit ProposalStatusChanged(proposalId, ProposalStatus.COMMIT, ProposalStatus.QUEUED);
        emit ProposalQueued(proposalId);
    }

    function moveToReady(uint256 proposalId) external override {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == ProposalStatus.QUEUED, "ProposalEngine: invalid stage");
        require(timeLockEngine.isExecutable(proposalId), "ProposalEngine: not executable");

        prop.status = ProposalStatus.READY;
        emit ProposalStatusChanged(proposalId, ProposalStatus.QUEUED, ProposalStatus.READY);
        emit ProposalReady(proposalId);
    }

    function execute(uint256 proposalId) external {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == ProposalStatus.READY, "ProposalEngine: not ready");
        timeLockEngine.execute(proposalId, prop.target, _proposalCallData[proposalId], prop.value);
    }

    function markExecuted(uint256 proposalId) external override {
        Proposal storage prop = proposals[proposalId];
        require(prop.status == ProposalStatus.READY, "ProposalEngine: invalid stage");
        require(msg.sender == address(timeLockEngine), "ProposalEngine: only timelock engine");

        prop.status = ProposalStatus.EXECUTED;
        if (_activeProposalCount[prop.proposer] > 0) {
            _activeProposalCount[prop.proposer] -= 1;
        }
        emit ProposalStatusChanged(proposalId, ProposalStatus.READY, ProposalStatus.EXECUTED);
        emit ProposalExecutedState(proposalId);
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory proposal) {
        proposal = proposals[proposalId];
    }

    function getStatus(uint256 proposalId) external view override returns (ProposalStatus status) {
        status = proposals[proposalId].status;
    }

    function activeProposalCount(address proposer) external view override returns (uint256 count) {
        count = _activeProposalCount[proposer];
    }

    function minimumBond(ActionType, uint256) external pure override returns (uint256 bond) {
        bond = 0;
    }
}
