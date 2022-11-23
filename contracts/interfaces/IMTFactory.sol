// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMTFactory {
    event SetFeeTo(address prev, address curr);
    event SetDepositFeeRatio(uint256 prev, uint256 curr);
    event SetFeeToAt(address mtToken, address curr);
    event SetDepositFeeRatioAt(address mtToken, uint256 curr);

    event MTTokenCreate(address indexed from, address MTToken, uint256 id);

    function getMTToken(address from) external view returns (address rToken);

    function allMTTokens(uint256 id) external view returns (address rToken);

    function feeTo() external view returns (address payable);

    function depositFeeRatio() external view returns (uint256);

    function allMTTokensLength() external view returns (uint256);

    function createMTToken(
        string memory symbol_,
        uint256 cap_,
        uint256 tokenPerBlock_
    ) external returns (address pair);
}
