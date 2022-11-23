// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMTMiner {
    event SetPriceOracle(address prev, address curr);

    //==================== Params ====================//

    struct ForwardRequest {
        address mtToken;
        address from;
        address to;
        uint256 value; // in ETH
        uint256 gas;
        uint256 mtValue; // in MTToken
        uint256 tip; // in MTToken
        uint256 nonce;
        bytes data;
    }

    //==================== View Functions ====================//

    function priceOracle() external view returns (address);

    function getNonce(address mtToken, address from)
        external
        view
        returns (uint256);

    function verify(ForwardRequest calldata req, bytes calldata signature)
        external
        view
        returns (bool);

    //==================== Functions ====================//

    function setPriceOracle(address newPriceOracle_) external;

    function execute(ForwardRequest calldata req, bytes calldata signature)
        external
        payable
        returns (bool, bytes memory);
}
