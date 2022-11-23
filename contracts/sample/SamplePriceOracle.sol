// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/// @dev Test-purpose only.
contract SamplePriceOracle {
    function priceOf(address mtToken)
        external
        view
        returns (uint256 numerator, uint256 denominator)
    {
        return (1, 1); // same as ETH
    }

    function gasPriceOf(address mtToken)
        external
        view
        returns (uint256 numerator, uint256 denominator)
    {
        return (10, 1e9);
    }
}
