// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPriceOracle.sol";

import "../interfaces/IMTMiner.sol";

/**
 * @dev Reference: OpenZeppelin Contracts (metatx/MinimalForwarder.sol).
 */
contract MTMiner is IMTMiner, Ownable, EIP712("MTMiner", "1.0.0") {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    //==================== Params ====================//

    address public priceOracle;

    bytes32 private constant _TYPEHASH =
        keccak256(
            "ForwardRequest(address mtToken,address from,address to,uint256 value,uint256 gas,uint256 mtValue,uint256 tip,uint256 nonce,bytes data)"
        );

    /// @dev Map (mtToken -> address -> nonce).
    mapping(address => mapping(address => uint256)) private _nonces;

    //==================== Initialize ====================//

    constructor(address priceOracle_) {
        priceOracle = priceOracle_;

        emit SetPriceOracle(address(0), priceOracle_);
    }

    function setPriceOracle(address newPriceOracle_) external onlyOwner {
        address prev = priceOracle;
        priceOracle = newPriceOracle_;

        emit SetPriceOracle(prev, newPriceOracle_);
    }

    //==================== View Functions ====================//

    function getNonce(address mtToken, address from)
        public
        view
        returns (uint256)
    {
        return _nonces[mtToken][from];
    }

    function verify(ForwardRequest calldata req, bytes calldata signature)
        public
        view
        returns (bool)
    {
        bytes memory body = abi.encode(
            _TYPEHASH,
            req.mtToken,
            req.from,
            req.to,
            req.value,
            req.gas,
            req.mtValue,
            req.tip,
            req.nonce,
            keccak256(req.data)
        );

        address signer = _hashTypedDataV4(keccak256(body)).recover(signature);
        return
            (_nonces[req.mtToken][req.from] == req.nonce) &&
            (signer == req.from);
    }

    //==================== Functions ====================//

    /// @notice Approve MTToken to forwarder first.
    function execute(ForwardRequest calldata req, bytes calldata signature)
        public
        payable
        returns (bool, bytes memory)
    {
        require(
            verify(req, signature),
            "MinimalForwarder: signature does not match request"
        );
        _nonces[req.mtToken][req.from] = req.nonce + 1;

        address forwarder = msg.sender;

        // get MTTokens
        IERC20(req.mtToken).safeTransferFrom(req.from, forwarder, req.mtValue);

        // call
        (bool success, bytes memory returndata) = req.to.call{
            gas: req.gas,
            value: req.value
        }(abi.encodePacked(req.data, req.from));
        // Validate that the relayer has sent enough gas for the call.
        // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
        if (gasleft() <= req.gas / 63) {
            // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
            // neither revert or assert consume all gas since Solidity 0.8.0
            // https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require
            /// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }

        // TODO: gas refund
        // get gas fee in MTToken from the original msg.sender
        (uint256 numerator, uint256 denominator) = IPriceOracle(priceOracle)
            .gasPriceOf(req.mtToken);
        uint256 mtGas = (req.gas * numerator) / denominator;
        IERC20(req.mtToken).safeTransferFrom(
            req.from,
            forwarder,
            mtGas + req.tip
        );

        return (success, returndata);
    }
}
