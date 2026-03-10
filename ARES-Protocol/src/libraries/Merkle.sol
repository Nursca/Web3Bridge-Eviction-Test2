// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library Merkle {
    
    function hashLeaf(uint256 leafId, address claimer, uint256 amount) internal pure returns (bytes32 leaf) {
        leaf = keccak256(abi.encode(leafId, claimer, amount));
    }

    function hashPair(bytes32 leafA, bytes32 leafB) internal pure returns (bytes32 leafPair) {
        (bytes32 left, bytes32 right) = leafA < leafB ? (leafA, leafB) : (leafB, leafA);
        leafPair = keccak256(abi.encode(left, right));
    }

    function verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool valid) {
        if (proof.length == 0) {
            return leaf == root;
        }

        bytes32 compiled = leaf;

        uint256 _length = proof.length;
        for (uint256 i =0; i < _length;) {
            compiled = hashPair(compiled, proof[i]);
            unchecked { ++i; }
        }

        valid = compiled == root;
    }
}