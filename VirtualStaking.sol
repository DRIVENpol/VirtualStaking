/**

>>> DO NOT USE IN PRODUCTION
>>> THIS SMART CONTRACT WAS CREATED ONLY TO PRESENT A CONCEPT

 */

//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IToken {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title Virtual Staking Smart Contract
 * @notice Stake tokens for 30 days without sending them to a smart contract
 * @author Socarde Paul-Constantin, DRIVENlabs Inc.
 */

contract VirtualStaking is Ownable {

    /// @dev sToken = token for staking
    /// @dev rToken = token for reward
    IToken public sToken;
    IToken public rToken;

    /// @dev Link an address to it's staked amount
    mapping(address => uint256) public stakedByUser;

    /// @dev Period of time
    uint256 public period = 30 days;

    /// @dev Struct for user's deposits
    struct Deposit {
        uint256 id;
        uint256 amount;
        uint256 startDate;
        uint256 endDate;
        bool ended;
        address owner;
    }

    /// @dev Array of deposits
    Deposit[] public deposits;

    /// @dev Events
    event Stake(address indexed user, uint256 id, uint256 amount, uint256 startDate, uint256 enDate);
    event Unstake(address indexed user, uint256 id, uint256 amount, uint256 rewards);

    /// @dev Errors
    error NotEnoughReservesForRewards();
    error NotEnoughReservesForStaking();
    error BalanceBellowStakedAmount();
    error InvalidErc20Transfer();
    error InvalidDepositIndex();
    error CantUnstake();
    error WrongOwner();

    /// @dev Constructor
    constructor(address _sToken, address _rToken) {
        sToken = IToken(_sToken);
        rToken = IToken(_rToken);
    }

    /// @dev Stake function
    function stake(uint256 amount) external returns(bool) {
        uint256 _balance = sToken.balanceOf(msg.sender);
        if(_balance + stakedByUser[msg.sender] < amount) revert NotEnoughReservesForStaking();
        stakedByUser[msg.sender] += amount;

        Deposit memory newDeposit = Deposit(deposits.length, amount, block.timestamp, block.timestamp + period, false, msg.sender);
        deposits.push(newDeposit);

        emit Stake(msg.sender, deposits.length, amount, block.timestamp, block.timestamp + period);

        return true;
    }

    /// @dev Unstake & get rewards function
    function unstakeAndTakeRewards(uint256 id) external returns(bool) {
        if(id >= deposits.length) revert InvalidDepositIndex();
        Deposit memory deposit = deposits[id];
        if(sToken.balanceOf(msg.sender) <= deposit.amount) revert BalanceBellowStakedAmount();
        if(msg.sender != deposit.owner) revert WrongOwner();
        if(block.timestamp <= deposit.endDate) revert CantUnstake();

        deposits[id].ended = true;
        deposits[id].amount = 0;

        uint256 _pendingRewards = _computeRewards(deposit.amount);

        rToken.transferFrom(address(this), msg.sender, _pendingRewards);

        emit Unstake(msg.sender, id, deposit.amount, _pendingRewards);

        return true;
    }

    /// @dev Internal function to compute rewards
    function _computeRewards(uint256 amount) internal view returns(uint256) {
        uint256 rate = 30; // 30%
        uint256 rewards = amount * rate / 100;

        if(rewards > rToken.balanceOf(address(this))) revert NotEnoughReservesForRewards();

        return rewards;
    }
}
