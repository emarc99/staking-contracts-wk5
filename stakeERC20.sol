// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract ERC20Staking {
    address public owner;
    address public tokenAddress;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool claimed;
    }

    uint256 public rewardRate = 100;
    mapping(address => Stake) public stakes;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);
    event RewardPaid(address indexed user, uint256 indexed reward);

    constructor(address _tokenAddress) {
        owner = msg.sender;
        tokenAddress = _tokenAddress;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    // Stake tokens
    function stake(uint256 _amount) external {
        require(msg.sender != address(0), "Zero address detected");
        require(_amount > 0, "Cannot stake zero tokens");

        uint256 userTokenBalance = IERC20(tokenAddress).balanceOf(msg.sender);
        require(userTokenBalance >= _amount, "Insufficient balance");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount);

        // Calculate any pending rewards for the user
        uint256 reward = calculateReward(msg.sender);

        // Update user's stake
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].startTime = block.timestamp;

        // Update rewards
        rewards[msg.sender] += reward;

        emit Staked(msg.sender, _amount);
    }

    // Calculate rewards based on staked amount and duration
    function calculateReward(address _user) public view returns (uint256) {
        Stake memory userStake = stakes[_user];
        if (userStake.amount == 0 || userStake.claimed) {
            return 0;
        }
        uint256 stakingDuration = block.timestamp - userStake.startTime;
        uint256 reward = (userStake.amount * stakingDuration * rewardRate) / 1e18;
        return reward;
    }

    // Withdraw staked tokens and rewards
    function withdraw(uint256 _amount) external {
        Stake storage userStake = stakes[msg.sender];
        require(_amount > 0, "Cannot withdraw zero tokens");
        require(userStake.amount >= _amount, "Insufficient staked amount");

        uint256 reward = calculateReward(msg.sender);

        // Reduce staked amount
        userStake.amount -= _amount;
        if (userStake.amount == 0) {
            userStake.claimed = true;
        }

        // Transfer staked tokens back to user
        IERC20(tokenAddress).transfer(msg.sender, _amount);

        // Pay rewards
        if (reward > 0) {
            rewards[msg.sender] += reward;
            payable(msg.sender).transfer(reward);  // Assuming rewards are paid in Ether
        }

        emit Withdrawn(msg.sender, _amount);
        emit RewardPaid(msg.sender, reward);
    }

    // View user's current balance in the staking contract
    function myBalance() external view returns (uint256) {
        return stakes[msg.sender].amount;
    }

    // Owner can set a new reward rate
    function setRewardRate(uint256 _newRate) external onlyOwner {
        rewardRate = _newRate;
    }

    // Owner can withdraw tokens from the contract (if needed)
    function ownerWithdraw(uint256 _amount) external onlyOwner {
        require(IERC20(tokenAddress).balanceOf(address(this)) >= _amount, "Insufficient funds");
        IERC20(tokenAddress).transfer(owner, _amount);
    }
    
    // Fallback function to accept Ether for rewards
    receive() external payable {}
}