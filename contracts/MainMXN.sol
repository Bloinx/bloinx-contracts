// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./SavingGroups.sol";
import "./BLXToken.sol";

contract Main is AccessControl {

    address public devFund = 0x4bFaF8ff960622b702e653C18b3bF747Abab4368;
    uint256 public fee = 5;
    IAccessControl public Iblx;
    BLXToken public blx;
    uint256 public deployDate = 1685577600; //June/01/2023
    uint256 public trim;

    event RoundCreated(SavingGroups childRound);

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createRound(   uint256 _warranty,
                            uint256 _saving,
                            uint256 _groupSize,
                            uint256 _adminFee,
                            uint256 _payTime,
                            ERC20 _token,
                            address _blxaddr
                        ) external payable returns(address) {
        Iblx=IAccessControl(_blxaddr);
        blx=BLXToken(_blxaddr);
        trim = (block.timestamp - deployDate) / 7776000;
        SavingGroups newRound = new SavingGroups(   _warranty,
                                                    _saving,
                                                    _groupSize,
                                                    msg.sender,
                                                    _adminFee,
                                                    _payTime,
                                                    _token,
                                                    blx,
                                                    devFund,
                                                    fee,
                                                    trim
                                                );
        Iblx.grantRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, address(newRound));  //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45
        emit RoundCreated(newRound);
        return address(newRound);
    }

    function setDevFundAddress (address _devFund) public onlyRole(DEFAULT_ADMIN_ROLE){//admin 0x0000000000000000000000000000000000000000000041444d494e5f524f4c45
        devFund = _devFund;
    }

    function setFee (uint256 _fee) public onlyRole(DEFAULT_ADMIN_ROLE){//admin 0x0000000000000000000000000000000000000000000041444d494e5f524f4c45
        fee = _fee;
    }

}
