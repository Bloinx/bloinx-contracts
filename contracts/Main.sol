// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./SavingGroups.sol";
import "./SavingGroupsMXN.sol";
import "./BLXToken.sol";

contract Main is AccessControl {
    address public devFund = 0xd1Fa9e091f65027F897FC3F911032C3ec8390D3f;
    uint256 public fee = 5;
    IAccessControl public Iblx;
    BLXToken public blx;

    event UsdRoundCreated(SavingGroups childRound);
    event MxnRoundCreated(SavingGroupsMXN childRoundMXN);

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createRoundUSD(
        uint256 _warranty,
        uint256 _saving,
        uint256 _groupSize,
        uint256 _adminFee,
        uint256 _payTime,
        ERC20 _token,
        address _blxaddr
    ) external payable returns (address) {
        Iblx = IAccessControl(_blxaddr);
        blx = BLXToken(address(0));
        require(
            ERC20(_token) != ERC20(0xBD1fe73e1f12bD2bc237De9b626F056f21f86427),
            "MXN not allowed"
        );
        SavingGroups newRound = new SavingGroups(
            _warranty,
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
        //Iblx.grantRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, address(newRound));  //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45
        emit UsdRoundCreated(newRound);
        return address(newRound);
    }

    function createRoundMXN(
        uint256 _warranty,
        uint256 _saving,
        uint256 _groupSize,
        uint256 _adminFee,
        uint256 _payTime,
        address _blxaddr
    ) external payable returns (address) {
        Iblx = IAccessControl(_blxaddr);
        blx = BLXToken(address(0));
        SavingGroupsMXN newRound = new SavingGroupsMXN(
            _warranty,
            _saving,
            _groupSize,
            msg.sender,
            _adminFee,
            _payTime,
            ERC20(0xBD1fe73e1f12bD2bc237De9b626F056f21f86427),
            blx,
            devFund,
            fee
        );
        //Iblx.grantRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, address(newRound));  //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45
        emit MxnRoundCreated(newRound);
        return address(newRound);
    }

    function setDevFundAddress(
        address _devFund
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        //admin 0x0000000000000000000000000000000000000000000041444d494e5f524f4c45
        devFund = _devFund;
    }

    function setFee(uint256 _fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        //admin 0x0000000000000000000000000000000000000000000041444d494e5f524f4c45
        fee = _fee;
    }
}
