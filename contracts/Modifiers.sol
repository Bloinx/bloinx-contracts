// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.18;

abstract contract Modifiers {
    modifier onlyAdmin(address admin) {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    modifier isRegisteredUser(bool user) {
        //Verifies if it is the users round to widraw
        require(user == true, "Usuario no registrado");
        _;
    }
}
