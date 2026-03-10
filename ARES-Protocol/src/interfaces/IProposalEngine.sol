// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface Proposal {
    function addProposal(address propser, uint amount, string memory message) external;
}