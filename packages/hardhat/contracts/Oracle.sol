// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// RWAOracle Contract
contract RWAOracle {
    address public admin;
    mapping(address => uint256) public prices;

    event PriceUpdated(address indexed token, uint256 price);

    constructor() {
        admin = msg.sender;
    }

    function setPrice(address token, uint256 price) external {
        require(msg.sender == admin, "Only admin can update prices");
        prices[token] = price;
        emit PriceUpdated(token, price);
    }

    function getPrice(address token) external view returns (uint256) {
        return prices[token];
    }
}