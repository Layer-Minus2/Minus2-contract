// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";

import "../interfaces/IMTERC20.sol";

/// @title Minus-Two ERC20 implementation.
/// @notice Personal token. Deposit ETHs then earn some MTERC20s. PoX!
/// @author lukepark327@gmail.com
contract MTERC20 is
    IMTERC20,
    Ownable,
    Pausable,
    ERC20Capped,
    ERC20Burnable,
    ERC20VotesComp
{
    using SafeERC20 for IERC20;

    //==================== Params ====================//

    uint256 public immutable TOKEN_PER_BLOCK;
    uint256 private constant _ACC_TOKEN_PRECISION = 1e12;

    /// @notice Info of each user that stakes ETHs.
    mapping(address => UserInfo) public userInfo;

    uint256 public lastRewardBlock = block.number;
    uint256 public accTokenPerShare;
    address public factory;
    address public creator;
    uint256 public totalDeposited;
    address payable public feeTo;

    uint256 public depositFeeRatio; // scale 10000
    uint256 internal constant _DENOMINATOR = 10000;

    //==================== Modifier ====================//

    modifier onlyFactory() {
        require(_msgSender() == factory, "MTERC20::onlyFactory: FORBIDDEN");
        _;
    }

    //==================== Initialize ====================//

    // For example, tokenPerBlock = 2 * 1e18;
    // about 30 years to reach cap (in the case of block interval 2s).
    constructor(
        string memory symbol,
        uint256 cap, // 2^256-1 for no upper bound // 1e18 scale.
        uint256 tokenPerBlock,
        address payable feeTo_,
        uint256 depositFeeRatio_
    )
        ERC20Capped(cap)
        ERC20(string.concat("Minus-Two", symbol), string.concat("mt", symbol))
        ERC20Permit(string.concat("mt", symbol))
    {
        factory = _msgSender();
        TOKEN_PER_BLOCK = tokenPerBlock;
        feeTo = feeTo_;
        depositFeeRatio = depositFeeRatio_;

        emit SetFeeTo(address(0), feeTo_);
    }

    // called once by the factory at time of deployment
    function initialize(address creator_) external onlyFactory {
        creator = creator_;

        _pause(); // lock withdraw
        _transferOwnership(creator_); // transfer ownership from `factory` to `creator`
    }

    function setFeeTo(address payable newFeeTo_) external onlyFactory {
        address prev = feeTo;
        feeTo = newFeeTo_;

        emit SetFeeTo(prev, newFeeTo_);
    }

    function setDepositFeeRatio(uint256 newDepositFeeRatio_)
        external
        onlyFactory
    {
        uint256 prev = depositFeeRatio;
        depositFeeRatio = newDepositFeeRatio_;

        emit SetDepositFeeRatio(prev, newDepositFeeRatio_);
    }

    //==================== Pausable ====================//

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //==================== MasterChef ====================//

    /// @notice View function to see pending MTERC20s on frontend.
    /// @param user_ Address of user.
    /// @return pending MTERC20 reward for a given user.
    function pendingToken(address user_) public view returns (uint256 pending) {
        UserInfo storage user = userInfo[user_];
        uint256 _accTokenPerShare = accTokenPerShare;
        uint256 _totalDeposited = totalDeposited;
        if (block.number > lastRewardBlock && _totalDeposited != 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 tokenReward = blocks * TOKEN_PER_BLOCK;
            _accTokenPerShare +=
                (tokenReward * _ACC_TOKEN_PRECISION) /
                _totalDeposited;
        }
        pending = uint256(
            int256((user.amount * _accTokenPerShare) / _ACC_TOKEN_PRECISION) -
                user.rewardDebt
        );
    }

    /// @notice Update reward variables to be up-to-date.
    function update() public {
        if (block.number > lastRewardBlock) {
            uint256 _totalDeposited = totalDeposited;
            if (_totalDeposited > 0) {
                uint256 blocks = block.number - lastRewardBlock;
                uint256 tokenReward = blocks * TOKEN_PER_BLOCK;
                accTokenPerShare +=
                    (tokenReward * _ACC_TOKEN_PRECISION) /
                    _totalDeposited;

                _mint(address(this), tokenReward);
            }
            lastRewardBlock = block.number;

            emit Update(lastRewardBlock, _totalDeposited, accTokenPerShare);
        }
    }

    /// @notice Deposit  tokens to MTERC20 for MTERC20 allocation.
    /// @param to_ The receiver of `amount` deposit benefit.
    function deposit(address to_) public payable {
        update();

        address msgSender = _msgSender();
        uint256 msgValue = msg.value;

        if (feeTo != address(0) || depositFeeRatio != 0) {
            (bool succeed, ) = feeTo.call{
                value: (msgValue * depositFeeRatio) / _DENOMINATOR
            }("");
            require(succeed, "MTERC20::withdraw: Fail to send ETHs.");
        }

        UserInfo storage user = userInfo[msgSender];

        totalDeposited += msgValue;
        user.amount += msgValue;
        user.rewardDebt += int256(
            (msgValue * accTokenPerShare) / _ACC_TOKEN_PRECISION
        );

        emit Deposit(msgSender, msgValue, to_);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param to_ Receiver of MTERC20 rewards.
    function harvest(address to_) public {
        update();

        address msgSender = _msgSender();
        UserInfo storage user = userInfo[msgSender];

        int256 accumulatedToken = int256(
            (user.amount * accTokenPerShare) / _ACC_TOKEN_PRECISION
        );
        uint256 _pendingToken = uint256(accumulatedToken - user.rewardDebt);

        user.rewardDebt = accumulatedToken;

        if (_pendingToken != 0) {
            _safeTokenTransfer(to_, _pendingToken);
        }

        emit Harvest(msgSender, _pendingToken, to_);
    }

    /// @notice Withdraw ETHs from MTERC20.
    /// @dev Withdraws totalDeposited-balance-Ratio weighted ETHs.
    /// @param amount_ of ETHs to withdraw.
    /// @param to_ Receiver of the ETHs.
    function withdraw(uint256 amount_, address payable to_)
        public
        whenNotPaused
    {
        update();

        address msgSender = _msgSender();
        UserInfo storage user = userInfo[msgSender];

        user.rewardDebt -= int256(
            (amount_ * accTokenPerShare) / _ACC_TOKEN_PRECISION
        );
        user.amount -= amount_;

        uint256 _weightedAmount = (amount_ * address(this).balance) /
            totalDeposited;
        totalDeposited -= amount_;
        (bool succeed, ) = to_.call{value: _weightedAmount}("");
        require(succeed, "MTERC20::withdraw: Fail to send ETHs.");

        emit Withdraw(msgSender, _weightedAmount, to_);
    }

    /// @notice Withdraw tokens and harvest proceeds for transaction sender to `to`.
    /// @dev Withdraws totalDeposited-balance-Ratio weighted ETHs.
    /// @param amount_ of ETHs to withdraw.
    /// @param to_ Receiver of the ETHs and MTERC20 rewards.
    function withdrawAndHarvest(uint256 amount_, address payable to_)
        public
        whenNotPaused
    {
        update();

        address msgSender = _msgSender();
        UserInfo storage user = userInfo[msgSender];

        int256 accumulatedToken = int256(
            (user.amount * accTokenPerShare) / _ACC_TOKEN_PRECISION
        );
        uint256 _pendingToken = uint256(accumulatedToken - user.rewardDebt);

        user.rewardDebt =
            accumulatedToken -
            int256((amount_ * accTokenPerShare) / _ACC_TOKEN_PRECISION);
        user.amount -= amount_;

        if (_pendingToken != 0) {
            _safeTokenTransfer(to_, _pendingToken);
        }

        uint256 _weightedAmount = (amount_ * address(this).balance) /
            totalDeposited;
        totalDeposited -= amount_;
        (bool succeed, ) = to_.call{value: _weightedAmount}("");
        require(succeed, "MTERC20::withdraw: Fail to send ETHs.");

        emit Withdraw(msgSender, _weightedAmount, to_);
        emit Harvest(msgSender, _pendingToken, to_);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @dev Withdraws totalDeposited-balance-Ratio weighted ETHs.
    /// @param to_ Receiver of the ETHs.
    function emergencyWithdraw(address payable to_) public whenNotPaused {
        address msgSender = _msgSender();
        UserInfo storage user = userInfo[msgSender];

        user.amount = 0;
        user.rewardDebt = 0;

        uint256 _weightedAmount = (user.amount * address(this).balance) /
            totalDeposited;
        totalDeposited -= user.amount;
        (bool succeed, ) = to_.call{value: _weightedAmount}("");
        require(succeed, "MTERC20::withdraw: Fail to send ETHs.");

        emit EmergencyWithdraw(msgSender, _weightedAmount, to_);
    }

    /// @notice Safe token transfer function,
    /// just in case if rounding error causes this contract to not have enough Tokens.
    function _safeTokenTransfer(address to_, uint256 amount_) internal {
        uint256 tokenBal = balanceOf(address(this));
        if (amount_ > tokenBal) {
            _transfer(address(this), to_, tokenBal);
        } else {
            _transfer(address(this), to_, amount_);
        }
    }

    //==================== Inherited Functions ====================//

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     *
     * See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped, ERC20Votes)
    {
        // require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        if (ERC20.totalSupply() + amount > cap()) {
            ERC20Votes._mint(account, cap() - ERC20.totalSupply());
        } else {
            ERC20Votes._mint(account, amount);
        }
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     * Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function _burn(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Votes)
    {
        ERC20Votes._burn(account, amount);
    }

    /**
     * @dev Move voting power when tokens are transferred.
     *
     * Emits a {DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }
}
