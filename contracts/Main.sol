// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.0;

import "./SavingGroups.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/access/AccessControl.sol";//"@openzeppelin/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/access/IAccessControl.sol";

contract Main is AccessControl {

    address public devAddress = 0x4bFaF8ff960622b702e653C18b3bF747Abab4368;
    IAccessControl public blx;

    event RoundCreated(SavingGroups childRound);

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createRound(uint256 _warranty , uint256 _saving, uint256 _groupSize, uint256 _adminFee, uint256 _payTime, IERC20 _token, IAccessControl _blxtoken) external payable returns(address) {

        SavingGroups newRound = new SavingGroups(_warranty, _saving, _groupSize, msg.sender, _adminFee, _payTime, _token , devAddress);
        blx=_blxtoken;
        blx.grantRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, address(newRound));//minter
        emit RoundCreated(newRound);
        return address(newRound);
    }

    function setDevAddress (address _devAddress) public onlyRole(0x0000000000000000000000000000000000000000000041444d494e5f524f4c45){//admin
        devAddress = _devAddress;
    }

}
