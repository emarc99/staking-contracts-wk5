// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EtherStaking {
    address public owner;
    uint256 public rewardRatePerSecond; 
    uint256 public minimumStakingTime = 1 days; // 

    struct Stake {
        uint256 amount;      
        uint256 startTime;      
        bool withdrawn;         
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount, uint256 startTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardRateUpdated(uint256 newRewardRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier hasStaked() {
        require(stakes[msg.sender].amount > 0, "No staked amount found");
        _;
    }

    constructor(uint256 _rewardRatePerSecond) {
        owner = msg.sender;
        rewardRatePerSecond = _rewardRatePerSecond;
    }

    // Function to update reward rate per second
    function updateRewardRate(uint256 _newRate) external onlyOwner {
        rewardRatePerSecond = _newRate;
        emit RewardRateUpdated(_newRate);
    }

    // Function to stake Ether
    function stake() external payable {
        require(msg.value > 0, "Cannot stake zero Ether");
        require(stakes[msg.sender].amount == 0, "Existing stake detected, withdraw first");

        stakes[msg.sender] = Stake({
            amount: msg.value,
            startTime: block.timestamp,
            withdrawn: false
        });

        emit Staked(msg.sender, msg.value, block.timestamp);
    }

    // View user's current balance in the staking contract
    function myBalance() external view returns (uint256) {
        return stakes[msg.sender].amount;
    }

    // Function to calculate the reward based on staking duration
    function calculateReward(address _user) public view returns (uint256) {
        Stake memory userStake = stakes[_user];
        if (userStake.amount == 0 || userStake.withdrawn) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - userStake.startTime;

        // Calculate reward only if staking duration exceeds the minimum required time
        if (stakingDuration >= minimumStakingTime) {
            return (userStake.amount * stakingDuration * rewardRatePerSecond) / 1e18;
        } else {
            return 0;
        }
    }

    // Function to withdraw staked Ether and rewards
    function withdraw() external hasStaked {
        Stake storage userStake = stakes[msg.sender];
        require(!userStake.withdrawn, "Already withdrawn");

        // Calculate rewards
        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = userStake.amount + reward;

        // Update stake status
        userStake.withdrawn = true;

        // Transfer Ether and rewards to the user
        (bool sent, ) = msg.sender.call{value: totalAmount}("");
        require(sent, "Failed to send Ether");

        emit Withdrawn(msg.sender, userStake.amount, reward);
    }

    // Function to check the user's staking details
    function getStakeDetails(address _user) external view returns (uint256 stakedAmount, uint256 reward, uint256 startTime) {
        Stake memory userStake = stakes[_user];
        stakedAmount = userStake.amount;
        reward = calculateReward(_user);
        startTime = userStake.startTime;
    }

}
