// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IProposalEngine.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../libraries/Signature.sol";
import "./GovernanceGuard.sol";

contract SignatureVerifier is ISignatureVerifier, GovernanceGuard {
    using Signature for bytes32;

    address public proposalEngine;
    string public name;
    string public version;

    mapping(address => bool) public signers;
    mapping(uint256 => mapping(address => bool)) public override hasSigned;
    mapping(uint256 => uint256) public override signatureCount;
    mapping(uint8 => uint256) public thresholds;
    mapping(address => uint256) public override getNonce;

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ThresholdSet(uint8 indexed actionType, uint256 threshold);

    constructor(address[] memory initialGovernors, string memory _name, string memory _version) {
        _initializeGovernance(initialGovernors);
        name = _name;
        version = _version;
    }

    function setProposalEngine(address _proposalEngine) external onlyGovernor {
        require(_proposalEngine != address(0), "SignatureVerifier: zero proposal engine");
        proposalEngine = _proposalEngine;
    }

    function addSigner(address signer) external onlyGovernor {
        require(signer != address(0), "SignatureVerifier: zero signer");
        require(!signers[signer], "SignatureVerifier: already signer");
        signers[signer] = true;
        emit SignerAdded(signer);
    }

    function removeSigner(address signer) external onlyGovernor {
        require(signers[signer], "SignatureVerifier: not signer");
        signers[signer] = false;
        emit SignerRemoved(signer);
    }

    function setThreshold(uint8 actionType, uint256 threshold) external onlyGovernor {
        require(threshold > 0, "SignatureVerifier: threshold zero");
        thresholds[actionType] = threshold;
        emit ThresholdSet(actionType, threshold);
    }

    function getThreshold(uint8 actionType) external view override returns (uint256 threshold) {
        threshold = thresholds[actionType];
    }

    function getDomainSeparator() public view override returns (bytes32 domainSeparator) {
        domainSeparator = Signature.buildDomainSeparator(name, version);
    }

    function computeDigest(uint256 proposalId, uint256 signerNonce, uint256 deadline, bytes32 payloadHash)
        public
        view
        override
        returns (bytes32 digest)
    {
        bytes32 structHash = Signature.hashSignaturePayLoad(proposalId, signerNonce, block.chainid, deadline, payloadHash);
        digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), structHash));
    }

    function submitSignature(uint256 proposalId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(proposalEngine != address(0), "SignatureVerifier: proposal engine not set");
        IProposalEngine.Proposal memory prop = IProposalEngine(proposalEngine).getProposal(proposalId);
        require(prop.status == IProposalEngine.ProposalStatus.COMMIT, "SignatureVerifier: proposal not commit");
        require(block.timestamp <= deadline, "SignatureVerifier: expired signature");

        address signer = ecrecover(computeDigest(proposalId, getNonce[msg.sender], deadline, prop.payloadHash), v, r, s);
        require(signer == msg.sender, "SignatureVerifier: signer mismatch");
        require(signers[signer], "SignatureVerifier: not approved signer");
        require(!hasSigned[proposalId][signer], "SignatureVerifier: already signed");

        // malleability protection
        require(uint256(s) <= uint256(Signature.SECP256K1_HALF_ORDER), "SignatureVerifier: invalid s");
        require(v == 27 || v == 28, "SignatureVerifier: invalid v");

        hasSigned[proposalId][signer] = true;
        signatureCount[proposalId] += 1;
        uint8 actionType = uint8(prop.actionType);
        uint256 threshold = thresholds[actionType];
        require(threshold > 0, "SignatureVerifier: threshold not set");

        emit SignatureRecorded(proposalId, signer, signatureCount[proposalId], threshold);

        if (signatureCount[proposalId] >= threshold) {
            emit ThresholdReached(proposalId, signatureCount[proposalId]);
        }

        getNonce[signer] += 1;
        emit NonceIncremented(signer, getNonce[signer] - 1, getNonce[signer]);
    }
}
