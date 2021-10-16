// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./SavingGroups.sol";

contract Main{
    event RoundCreated(SavingGroups childRound);

    function createRound(uint256 _warranty, uint256 _saving, uint256 _groupSize, uint256 _payTime) external payable returns(address) {

        SavingGroups newRound = new SavingGroups(_warranty, _saving, _groupSize, msg.sender, _payTime);
        emit RoundCreated(newRound);
        return address(newRound);
    }
}
