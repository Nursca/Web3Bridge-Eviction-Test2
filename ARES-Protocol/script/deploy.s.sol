// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/modules/TimeLockEngine.sol";
import "../src/modules/SignatureVerifier.sol";
import "../src/modules/ProposalEngine.sol";
import "../src/modules/RewardDistributor.sol";
import "../src/core/AresTreasury.sol";

contract DeployScript is Script {
    function run() external {
        address[] memory governors = new address[](3);
        governors[0] = vm.addr(0x1001);
        governors[1] = vm.addr(0x1002);
        governors[2] = vm.addr(0x1003);

        vm.startBroadcast();
        TimeLockEngine timelock = new TimeLockEngine(governors, 1 hours, 1 hours);
        SignatureVerifier sigVerifier = new SignatureVerifier(governors, "ARES", "1");
        ProposalEngine proposal = new ProposalEngine(governors, address(sigVerifier), address(timelock));
        RewardDistributor rewards = new RewardDistributor(governors);
        AresTreasury treasury = new AresTreasury(governors);

        sigVerifier.setProposalEngine(address(proposal));
        timelock.setProposalEngine(address(proposal));
        proposal.setSignatureVerifier(address(sigVerifier));
        proposal.setTimeLockEngine(address(timelock));
        treasury.setModules(address(proposal), address(timelock));

        vm.stopBroadcast();

        // console.log("Deployed:", address(timelock), address(sigVerifier), address(proposal), address(rewards), address(treasury));
    }
}
