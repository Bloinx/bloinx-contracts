// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.0;

import "./SavingGroups.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Main is Ownable{

    address public devAddress = 0x4bFaF8ff960622b702e653C18b3bF747Abab4368;

    event RoundCreated(SavingGroups childRound);

    function createRound(
        uint256 _warranty ,
        uint256 _saving,
        uint256 _groupSize,
        uint256 _adminFee,
        uint256 _payTime,
        IERC20 _token
    ) external payable returns(address) {

        SavingGroups newRound = new SavingGroups(
            _warranty,
            _saving,
            _groupSize,
            msg.sender,
            _adminFee,
            _payTime,
            _token ,
            devAddress
        );
        emit RoundCreated(newRound);
        return address(newRound);
    }

    function setDevAddress (address _devAddress) public onlyOwner{
        devAddress = _devAddress;
    }
}
