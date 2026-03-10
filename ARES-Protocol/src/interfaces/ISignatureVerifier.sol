// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
interface ISignatureVerifier {

    struct SignaturePayLoad {
        uint256 proposalId;
        uint256 signerNonce;
        uint256 chainId;
        uint256 deadline;
        bytes32 payloadHash;
    }

    event SignatureRecorded(uint256 indexed proposal, address indexed signer, uint256 sigCount, uint256 threshold);

    event ThresholdReached(uint256 indexed proposalId, uint256 sigCount);

    event NonceIncremented(address indexed signer, uint256 oldNonce, uint256 newNonce);


    function submitSignature(uint256 proposalId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function getNonce(address signer) external view returns (uint256 nonce);

    function hasSigned(uint256 proposalId, address signer) external view returns (bool signed);

    function signatureCount(uint256 proposalId) external view returns (uint256 count);

    function getThreshold(uint8 actionType) external view returns (uint256 threshold);

    function getDomainSeparator() external view returns (bytes32 domainSeparator);

    function computeDigest(uint256 proposalId, uint256 signerNonce, uint256 deadline, bytes32 payloadHash) external view returns (bytes32 digest);
}