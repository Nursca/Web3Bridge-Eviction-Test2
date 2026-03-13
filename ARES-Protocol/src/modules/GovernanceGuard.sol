// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract GovernanceGuard {
    address public governor;
    mapping(address => bool) public isGovernor;

    uint256 public governorCount;

    event GovernorAdded(address indexed governor);
    event GovernorRemoved(address indexed governor);
    event GovernorshipTransferred(address indexed oldGovernor, address indexed newGovernor);

    modifier onlyGovernor() {
        require(isGovernor[msg.sender], "GovernanceGuard: caller is not governor");
        _;
    }

    function _initializeGovernance(address[] memory initialGovernors) internal {
        require(initialGovernors.length > 0, "GovernanceGuard: empty governors");
        governor = initialGovernors[0];
        for (uint256 i = 0; i < initialGovernors.length; i++) {
            address g = initialGovernors[i];
            require(g != address(0), "GovernanceGuard: zero governor");
            isGovernor[g] = true;
            governorCount += 1;
            emit GovernorAdded(g);
        }
    }

    function addGovernor(address newGovernor) external onlyGovernor {
        require(newGovernor != address(0), "GovernanceGuard: zero governor");
        require(!isGovernor[newGovernor], "GovernanceGuard: already governor");
        isGovernor[newGovernor] = true;
        governorCount ++;
        emit GovernorAdded(newGovernor);
    }

    function removeGovernor(address oldGovernor) external onlyGovernor {
        require (governorCount > 1, "GovernanceGuard: cannot remove last governor");
        require(isGovernor[oldGovernor], "GovernanceGuard: not governor");
        require(oldGovernor != msg.sender, "GovernanceGuard: self removal not allowed");
        isGovernor[oldGovernor] = false;
        governorCount--;

        emit GovernorRemoved(oldGovernor);
    }

    function transferGovernorship(address newGovernor) external onlyGovernor {
        require(newGovernor != address(0), "GovernanceGuard: zero governor");
        address oldGovernor = governor;
        governor = newGovernor;
        isGovernor[oldGovernor] = false;
        isGovernor[newGovernor] = true;
        emit GovernorshipTransferred(oldGovernor, newGovernor);
    }
}
