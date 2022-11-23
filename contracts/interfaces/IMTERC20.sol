// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMTERC20 {
    //==================== Params ====================//

    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    function lastRewardBlock() external view returns (uint256);

    function accTokenPerShare() external view returns (uint256);

    function factory() external view returns (address);

    function creator() external view returns (address);

    function totalDeposited() external view returns (uint256);

    function feeTo() external view returns (address payable);

    function depositFeeRatio() external view returns (uint256);

    //==================== Events ====================//

    event SetFeeTo(address prev, address curr);
    event SetDepositFeeRatio(uint256 prev, uint256 curr);

    event Update(
        uint256 lastRewardBlock,
        uint256 totalDeposited,
        uint256 accTokenPerShare
    );
    event Deposit(address indexed user, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 amount, address indexed to);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount,
        address indexed to
    );

    //==================== Initialize ====================//

    function initialize(address creator_) external;

    function setFeeTo(address payable newFeeTo_) external;

    function setDepositFeeRatio(uint256 newDepositFeeRatio_) external;

    //==================== MasterChef ====================//

    function pendingToken(address user_)
        external
        view
        returns (uint256 pending);

    function update() external;

    function deposit(address to_) external payable;

    function harvest(address to_) external;

    /// @dev whenNotPaused
    function withdraw(uint256 amount_, address payable to_) external;

    /// @dev whenNotPaused
    function withdrawAndHarvest(uint256 amount_, address payable to_) external;

    /// @dev whenNotPaused
    function emergencyWithdraw(address payable to_) external;
}
