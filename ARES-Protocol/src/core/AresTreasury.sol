// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IProposalEngine.sol";
import "../interfaces/ITimeLockEngine.sol";
import "../modules/GovernanceGuard.sol";

contract AresTreasury is GovernanceGuard {
    ITimeLockEngine public timelockEngine;
    IProposalEngine public proposalEngine;

    uint256 public maxSingleTransfer = 100_000 ether;
    bool private _entered;

    event IncomingFunds(address indexed sender, uint256 amount);
    event TransferExecuted(address indexed token, address indexed to, uint256 amount);
    event CallExecuted(address indexed target, uint256 value, bytes data);

    modifier onlyTimelock() {
        require(msg.sender == address(timelockEngine), "AresTreasury: only timelock");
        _;
    }

    modifier nonReentrant() {
        require(!_entered, "AresTreasury: reentrancy");
        _entered = true;
        _;
        _entered = false;
    }

    constructor(address[] memory initialGovernors) {
        _initializeGovernance(initialGovernors);
    }

    receive() external payable {
        emit IncomingFunds(msg.sender, msg.value);
    }

    function setModules(address _proposalEngine, address _timelockEngine) external onlyGovernor {
        proposalEngine = IProposalEngine(_proposalEngine);
        timelockEngine = ITimeLockEngine(_timelockEngine);
    }

    function transferERC20(address token, address to, uint256 amount) external onlyTimelock nonReentrant {
        require(amount > 0, "AresTreasury: zero amount");
        require(amount <= maxSingleTransfer, "AresTreasury: transfer over limit");
        require(token != address(0), "AresTreasury: zero token");
        require(to != address(0), "AresTreasury: zero recipient");

        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "AresTreasury: token transfer failed");

        emit TransferExecuted(token, to, amount);
    }

    function executeCall(address target, uint256 value, bytes calldata data) external onlyTimelock nonReentrant {
        require(target != address(0), "AresTreasury: target zero");
        require(target != address(this), "AresTreasury cannot target self");
        require(target != address(timelockEngine), "AresTreasury: cannot target timelock");
        require(target != address(proposalEngine), "AresTreasury: cannot target proposal engine");

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, string(result));

        emit CallExecuted(target, value, data);
    }

    function setMaxSingleTransfer(uint256 amount) external onlyGovernor {
        maxSingleTransfer = amount;
    }
}
