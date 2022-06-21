// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.0;

import "./SavingGroups.sol";
<<<<<<< HEAD
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";//"@openzeppelin/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/IAccessControl.sol";
import "./BLXToken.sol";
=======
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
>>>>>>> develop

contract Main is AccessControl {

    address public devFund = 0x4bFaF8ff960622b702e653C18b3bF747Abab4368;
    uint256 public fee = 5;
    IAccessControl public Iblx;
    BLXToken public blx;

    event RoundCreated(SavingGroups childRound);

<<<<<<< HEAD
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
        SavingGroups newRound = new SavingGroups(   _warranty,
                                                    _saving,
                                                    _groupSize,
                                                    msg.sender,
                                                    _adminFee,
                                                    _payTime,
                                                    _token,
                                                    blx,
                                                    devFund,
                                                    fee
                                                );
        Iblx.grantRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, address(newRound));  //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45
=======
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
>>>>>>> develop
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
