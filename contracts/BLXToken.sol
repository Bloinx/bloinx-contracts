// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/access/AccessControl.sol";//"@openzeppelin/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/token/ERC20/ERC20.sol";//"https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";


contract BLXToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint 100 tokens to msg.sender
        // Similar to how
        // 1 dollar = 100 cents
        // 1 token = 1 * (10 ** decimals)
        _mint(msg.sender, 100 * 10**uint(decimals()));
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE,0x0813d4a158d06784FDB48323344896B2B1aa0F85);//This address is the Main.sol SC address
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }
}
