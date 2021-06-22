// SPDX-License-Identifier: MIT
pragma solidity ^0.7.2;

import "./SavingGroups.sol";

contract Main{
    event TandaCreated(SavingGroups childTanda);

    function createTanda(uint256 _garantia, uint256 _ahorro, uint256 _groupSize, uint256 _payTime, uint256 _withdrawTime) external payable returns(address) {

        SavingGroups newTanda = new SavingGroups(_garantia, _ahorro, _groupSize, msg.sender, _payTime, _withdrawTime);
        emit TandaCreated(newTanda);
        return address(newTanda);
    }
}
