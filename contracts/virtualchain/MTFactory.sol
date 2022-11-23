// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./MTERC20.sol";

import "../interfaces/IMTFactory.sol";

contract MTFactory is IMTFactory, Ownable {
    //==================== Params ====================//

    mapping(address => address) public getMTToken;
    address[] public allMTTokens;

    address payable public feeTo;
    uint256 public depositFeeRatio;

    //==================== Initialize ====================//

    constructor() {}

    function setFeeTo(address payable newFeeTo_) external onlyOwner {
        address prev = feeTo;
        feeTo = newFeeTo_;

        emit SetFeeTo(prev, newFeeTo_);
    }

    function setFeeToAt(address mtToken_, address payable newFeeTo_)
        external
        onlyOwner
    {
        IMTERC20(mtToken_).setFeeTo(newFeeTo_);

        emit SetFeeToAt(mtToken_, newFeeTo_);
    }

    function setDepositFeeRatio(uint256 newDepositFeeRatio_)
        external
        onlyOwner
    {
        uint256 prev = depositFeeRatio;
        depositFeeRatio = newDepositFeeRatio_;

        emit SetDepositFeeRatio(prev, newDepositFeeRatio_);
    }

    function setDepositFeeRatioAt(address mtToken_, uint256 newDepositFeeRatio_)
        external
        onlyOwner
    {
        IMTERC20(mtToken_).setDepositFeeRatio(newDepositFeeRatio_);

        emit SetDepositFeeRatioAt(mtToken_, newDepositFeeRatio_);
    }

    //==================== View Functions ====================//

    function allMTTokensLength() public view returns (uint256) {
        return allMTTokens.length;
    }

    //==================== Functions ====================//

    function createMTToken(
        string memory symbol_,
        uint256 cap_,
        uint256 tokenPerBlock_
    ) public returns (address) {
        address _msgSender = _msgSender();

        require(
            getMTToken[_msgSender] == address(0),
            "MTFactory::createMTToken: MTTOKEN_EXISTS."
        );

        bytes32 salt = keccak256(abi.encodePacked(_msgSender));
        MTERC20 mtToken = new MTERC20{salt: salt}(
            symbol_,
            cap_,
            tokenPerBlock_,
            feeTo,
            depositFeeRatio
        );
        mtToken.initialize(_msgSender);

        getMTToken[_msgSender] = address(mtToken);
        allMTTokens.push(address(mtToken));

        emit MTTokenCreate(_msgSender, address(mtToken), allMTTokens.length);

        return address(mtToken);
    }
}
