// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IAIOERC20
 * @notice Interface for AIOERC20 token contract
 */
interface IAIOERC20 {
    /**
     * @notice Transfers tokens from one address to another
     * @param to Address to receive tokens
     * @param amount Amount of tokens to transfer
     * @return success Whether the transfer succeeded
     */
    function transfer(address to, uint256 amount) external returns (bool success);

    /**
     * @notice Transfers tokens from one address to another (with allowance)
     * @param from Address to transfer from
     * @param to Address to receive tokens
     * @param amount Amount of tokens to transfer
     * @return success Whether the transfer succeeded
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool success);

    /**
     * @notice Returns the balance of tokens for an account
     * @param account Address to check balance for
     * @return balance Token balance
     */
    function balanceOf(address account) external view returns (uint256 balance);
}

