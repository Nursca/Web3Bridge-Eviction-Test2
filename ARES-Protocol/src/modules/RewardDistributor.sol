// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IRewardDistribution.sol";
import "../libraries/Merkle.sol";
import "./GovernanceGuard.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract RewardDistributor is IRewardDistribution, GovernanceGuard {
    using Merkle for bytes32;

    mapping(uint256 => Epoch) private epochs;
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;
    uint256 public epochCount;

    constructor(address[] memory initialGovernors) {
        _initializeGovernance(initialGovernors);
    }

    function createEpoch(bytes32 merkleRoot, address rewardToken, uint256 totalAmount, uint256 claimDeadline)
        external
        override
        onlyGovernor
        returns (uint256 epochId)
    {
        require(merkleRoot != bytes32(0), "RewardDistributor: root zero");
        require(rewardToken != address(0), "RewardDistributor: token zero");
        require(totalAmount > 0, "RewardDistributor: amount zero");
        require(claimDeadline > block.timestamp, "RewardDistributor: deadline in past");

        epochId = ++epochCount;
        epochs[epochId] = Epoch({
            epochId: epochId,
            merkleRoot: merkleRoot,
            rewardToken: rewardToken,
            totalAmount: totalAmount,
            claimedAmount: 0,
            activatedAt: 0,
            claimDeadline: claimDeadline,
            active: false
        });

        emit EpochCreated(epochId, merkleRoot, rewardToken, totalAmount);
    }

    function activateEpoch(uint256 epochId) external override onlyGovernor {
        Epoch storage ep = epochs[epochId];
        require(ep.epochId != 0, "RewardDistributor: epoch not found");
        require(!ep.active, "RewardDistributor: already active");

        ep.active = true;
        ep.activatedAt = block.timestamp;
    }

    function updateRoot(uint256 epochId, bytes32 newRoot) external override onlyGovernor {
        Epoch storage ep = epochs[epochId];
        require(ep.epochId != 0, "RewardDistributor: epoch not found");
        require(!ep.active, "RewardDistributor: active epoch cannot edit root");

        bytes32 oldRoot = ep.merkleRoot;
        ep.merkleRoot = newRoot;
        emit RootUpdated(epochId, oldRoot, newRoot);
    }

    function claim(uint256 epochId, uint256 amount, uint256 leafIndex, bytes32[] calldata proof) external override {
        Epoch storage ep = epochs[epochId];
        require(ep.active, "RewardDistributor: epoch not active");
        require(block.timestamp <= ep.claimDeadline, "RewardDistributor: claim period ended");

        require(!isClaimed(epochId, leafIndex), "RewardDistributor: already claimed");

        bytes32 leaf = computeLeaf(epochId, msg.sender, amount);
        require(Merkle.verify(proof, ep.merkleRoot, leaf), "RewardDistributor: invalid proof");

        _setClaimed(epochId, leafIndex);

        ep.claimedAmount += amount;
        require(ep.claimedAmount <= ep.totalAmount, "RewardDistributor: overclaim");

        require(IERC20(ep.rewardToken).transfer(msg.sender, amount), "RewardDistributor: transfer failed");
        emit RewardClaimed(epochId, msg.sender, amount, leafIndex);
    }

    function isClaimed(uint256 epochId, uint256 leafIndex) public view override returns (bool claimed) {
        uint256 wordIndex = leafIndex >> 8; // / 256
        uint256 bitIndex = leafIndex & 0xff;
        uint256 word = claimedBitMap[epochId][wordIndex];
        claimed = (word >> bitIndex) & 1 == 1;
    }

    function getEpoch(uint256 epochId) external view override returns (Epoch memory epoch) {
        epoch = epochs[epochId];
    }

    function getMerkleRoot(uint256 epochId) external view override returns (bytes32 root) {
        root = epochs[epochId].merkleRoot;
    }

    function computeLeaf(uint256 epochId, address claimer, uint256 amount) public pure override returns (bytes32 leaf) {
        leaf = keccak256(abi.encodePacked(epochId, claimer, amount));
    }

    function _setClaimed(uint256 epochId, uint256 leafIndex) internal {
        uint256 wordIndex = leafIndex >> 8;
        uint256 bitIndex = leafIndex & 0xff;
        claimedBitMap[epochId][wordIndex] |= (1 << bitIndex);
    }
}
