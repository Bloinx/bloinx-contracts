// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/access/AccessControl.sol";//"@openzeppelin/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/token/ERC20/ERC20.sol";//"https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";


contract BLXToken is ERC20, AccessControl {
    uint256 private immutable _cap;

    bytes32 public constant ADMIN_MINTER_ROLE = keccak256("ADMIN_MINTER_ROLE"); //admin minter 0x00000000000000000000000000000041444d494e5f4d494e5445525f524f4c45
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); //minter 0x0000000000000000000000000000000000000000004d494e5445525f524f4c45
    bytes32 public constant ADMIN_BURNER_ROLE = keccak256("ADMIN_BURNER_ROLE"); //admin minter 0x00000000000000000000000000000041444d494e5f4255524e45525f524f4c45
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE"); //burner 0x0000000000000000000000000000000000000000004255524e45525f524f4c45

    constructor(string memory name, string memory symbol, uint256 cap_) ERC20(name, symbol) {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(0x00000000000000000000000000000041444d494e5f4d494e5445525f524f4c45, DEFAULT_ADMIN_ROLE); //deployer can set admin minter role
        _setRoleAdmin(0x00000000000000000000000000000041444d494e5f4255524e45525f524f4c45, DEFAULT_ADMIN_ROLE); //deployer can set admin burner role
        _setRoleAdmin(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45, 0x00000000000000000000000000000041444d494e5f4d494e5445525f524f4c45); // admin minter can set minter role
        _setRoleAdmin(0x0000000000000000000000000000000000000000004255524e45525f524f4c45, 0x00000000000000000000000000000041444d494e5f4255524e45525f524f4c45); // admin burner can set burner role
    }

    function mint(address to, uint256 amount) public onlyRole(0x0000000000000000000000000000000000000000004d494e5445525f524f4c45){ //only minter
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        _mint(to, amount);
    }

        function burn(uint256 amount) public onlyRole(0x0000000000000000000000000000000000000000004255524e45525f524f4c45){
        _burn(msg.sender, amount);
    }

        function cap() public view virtual returns (uint256) {
        return _cap;
    }
}
