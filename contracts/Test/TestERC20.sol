// SPDX-License-Identifier: BSD 3-Clause License

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

contract TestERC20 is ERC20PresetMinterPauser {
    constructor() public ERC20PresetMinterPauser("TestERC20", "ERC20") {}
}
