// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRewardDistribution {
    
    struct Epoch {
        uint256 epochId;
        bytes32 merkleRoot;
        address rewardToken;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 activatedAt; 
        uint256 claimDeadline;
        bool active;
    }

    event EpochCreated(uint256 indexed epochId, bytes32 merkleRoot, address indexed rewardToken, uint256 totalAmount);

    event RootUpdated(uint256 indexed epochId, bytes32 oldRoot, bytes32 newRoot);

    event RewardClaimed(uint256 indexed epochId, address indexed claimant, uint256 amount, uint256 leafIndex);

    function createEpoch(bytes32 merkleRoot, address rewardToken, uint256 totalAmount, uint256 claimDeadline) external returns (uint256 epochId);

    function activateEpoch(uint256 epochId) external;

    function updateRoot(uint256 epochId, bytes32 newRoot) external;

    function claim(uint256 epochId, uint256 amount, uint256 leafIndex, bytes32[] calldata proof) external;

    function getEpoch(uint256 epochId) external view returns (Epoch memory epoch);

    function isClaimed(uint256 epochId, uint256 leafIndex) external view returns (bool claimed);

    function getMerkleRoot(uint256 epochId) external view returns (bytes32 root);

    function computeLeaf(uint256 epochId, address claimer, uint256 amount) external pure returns (bytes32 leaf);
}