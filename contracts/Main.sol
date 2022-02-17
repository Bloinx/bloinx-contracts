// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.7.6;

import "./SavingGroups.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4-solc-0.7/contracts/token/ERC20/IERC20.sol
contract Main {
    event RoundCreated(SavingGroups childRound);

    function createRound(uint256 _warranty, uint256 _saving, uint256 _groupSize, uint256 _payTime, IERC20 _token) external payable returns(address) {
        SavingGroups newRound = new SavingGroups(_warranty, _saving, _groupSize, msg.sender, _payTime, _token);
        emit RoundCreated(newRound);
        return address(newRound);
    }
}
