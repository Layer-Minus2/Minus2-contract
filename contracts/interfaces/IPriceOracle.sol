// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IPriceOracle {
    /// @dev in wei.
    function priceOf(address mtToken)
        external
        view
        returns (uint256 numerator, uint256 denominator);

    /// @dev in wei.
    function gasPriceOf(address mtToken)
        external
        view
        returns (uint256 numerator, uint256 denominator);
}
