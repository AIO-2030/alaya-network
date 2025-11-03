// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IFeeDistributor
 * @notice Interface for FeeDistributor contract
 */
interface IFeeDistributor {
    /**
     * @notice Returns the minimum ETH fee per interaction (in wei)
     * @return The minimum fee in wei
     */
    function feeWei() external view returns (uint256);

    /**
     * @notice Collects ETH fee from the caller and forwards to project wallet
     * @dev Requires msg.value >= feeWei()
     */
    function collectEth() external payable;

    /**
     * @notice Collects ERC20 token fee from the caller and forwards to project wallet
     * @param token The ERC20 token address
     * @param amount The amount of tokens to collect
     * @dev User must approve this contract beforehand
     */
    function collectErc20(address token, uint256 amount) external;
}

