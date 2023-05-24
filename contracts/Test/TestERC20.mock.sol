// SPDX-License-Identifier: BSD 3-Clause License

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

contract TestERC20 is ERC20PresetMinterPauser {
    constructor() public ERC20PresetMinterPauser("TestERC20", "ERC20") {}
}
