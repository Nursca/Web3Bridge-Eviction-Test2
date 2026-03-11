// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library TypeHashes {
    bytes32 internal constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    bytes32 internal constant SIGNATURE_PAYLOAD_TYPEHASH = keccak256(
        "SignaturePayload(uint256 proposalId, uint256 signerNonce, uint256 chainId, uint256 deadline, bytes32 payloadHash)"
    );
}

library Signature {
    
    bytes32 internal constant SECP256K1_HALF_ORDER = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    function buildDomainSeparator(string memory name, string memory version) internal view returns (bytes32 domainSeparator) {
        domainSeparator = keccak256(abi.encode(
            TypeHashes.DOMAIN_TYPEHASH,
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            block.chainid,
            address(this)
        ));
    }

    function hashSignaturePayLoad(uint256 proposalId, uint256 signerNonce, uint256 chainId, uint256 deadline, bytes32 payloadHash) internal pure returns (bytes32 structHash) {
        structHash = keccak256(abi.encode(
            TypeHashes.SIGNATURE_PAYLOAD_TYPEHASH,
            proposalId,
            signerNonce,
            chainId,
            deadline,
            payloadHash
        ));
    }

}