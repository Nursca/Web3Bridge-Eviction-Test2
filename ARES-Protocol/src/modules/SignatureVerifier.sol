// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IProposalEngine.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../libraries/Signature.sol";
import "./GovernanceGuard.sol";

abstract contract SignatureVerifier is ISignatureVerifier, GovernanceGuard {
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
        require(_proposalEngine != address(0), " zero proposal engine");
        proposalEngine = _proposalEngine;
    }

    function addSigner(address signer) external onlyGovernor {
        require(signer != address(0), " zero signer");
        require(!signers[signer], " already signer");
        signers[signer] = true;
        emit SignerAdded(signer);
    }

    function removeSigner(address signer) external onlyGovernor {
        require(signers[signer], " not signer");
        signers[signer] = false;
        emit SignerRemoved(signer);
    }

    function setThreshold(uint8 actionType, uint256 threshold) external onlyGovernor {
        require(threshold > 0, " threshold zero");
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

    function submitSignature(uint256 proposalId, uint256 deadline, address expectedSigner, uint8 v, bytes32 r, bytes32 s) external {
        uint256 nonce = getNonce[expectedSigner];

        require(proposalEngine != address(0), "proposal engine not set");
        IProposalEngine.Proposal memory prop = IProposalEngine(proposalEngine).getProposal(proposalId);

        bytes32 digest = computeDigest(proposalId, nonce, deadline, prop.payloadHash);

        address recovered = ecrecover(digest, v, r, s);
        require(recovered == expectedSigner, "signer mismatch");
        require(signers[recovered], "not approved signer");

        require(prop.status == IProposalEngine.ProposalStatus.COMMIT, "proposal not commit");
        require(block.timestamp <= deadline, "expired signature");
        require(v == 27 || v == 28, "invalid v");
        require(uint256(s) <= uint256(Signature.SECP256K1_HALF_ORDER), "invalid s");

        address signer = ecrecover(computeDigest(proposalId, getNonce[msg.sender], deadline, prop.payloadHash), v, r, s);
        require(signer != address(0), "invalid signature");
        require(signer == msg.sender, "signer mismatch");
        require(signers[signer], "not approved signer");
        require(!hasSigned[proposalId][signer], "already signed");

        hasSigned[proposalId][signer] = true;
        signatureCount[proposalId] += 1;
        uint8 actionType = uint8(prop.actionType);
        uint256 threshold = thresholds[actionType];
        require(threshold > 0, "threshold not set");

        emit SignatureRecorded(proposalId, signer, signatureCount[proposalId], threshold);

        if (signatureCount[proposalId] >= threshold) {
            emit ThresholdReached(proposalId, signatureCount[proposalId]);
        }

        getNonce[recovered] += 1;
        emit NonceIncremented(signer, getNonce[signer] - 1, getNonce[signer]);
    }
}
