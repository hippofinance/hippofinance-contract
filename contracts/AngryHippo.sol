pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AngryHippo is ERC20("AngryHippoV2", "aHIPPOv2"), Ownable {
    using SafeMath for uint256;

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Addresses
    address public devAddress;
    address public fundAddress;

    // Reward
    uint256 public rewardPerBlock;
    uint256 public rewardPerBlockLP;

    // Rate of Reward
    uint256 public rateDevFee = 5;
    uint256 public rateReward = 75;
    uint256 public rateFund = 20;
    uint256 public start_block = 0;

    // Addresses for stake
    IERC20 public HippoToken;
    IERC20 public HippoLPToken;

    // Start?
    bool public isStart;


    // Stakeaddress
    struct stakeTracker {
        uint256 lastBlock;
        uint256 lastBlockLP;
        uint256 rewards;
        uint256 rewardsLP;
        uint256 stakedHIPPO;
        uint256 stakedHippoLP;
    }
    mapping(address => stakeTracker) public staked;

    // Amount
    uint256 private totalStakedAmount = 0; // for HIPPO
    uint256 private totalStakedAmountLP = 0; // for HIPPO/ETH


    constructor(
        address hippoToken,
        address _devAddress,
        address _fundAddress,
        uint256 _start_block
    ) public {
        _mint(_msgSender(), 15000 * 1000000000000000000);
        devAddress = _devAddress;
        fundAddress = _fundAddress;
        rewardPerBlock = 2 * 1000000000000000000;
        rewardPerBlockLP = 3 * 1000000000000000000;
        start_block = _start_block;
        HippoToken = IERC20(address(hippoToken));
        isStart = false;
    }


    // Events
    event Staked(address indexed user, uint256 amount, uint256 total);
    event Unstaked(address indexed user, uint256 amount, uint256 total);
    event StakedLP(address indexed user, uint256 amount, uint256 total);
    event UnstakedLP(address indexed user, uint256 amount, uint256 total);
    event Rewards(address indexed user, uint256 amount);


    // Reward Updater
    modifier updateStakingReward(address account) {

        uint256 h = 0;
        uint256 lastBlock = staked[account].lastBlock;
        if(block.number > staked[account].lastBlock && totalStakedAmount != 0) {
            uint256 multiplier = block.number.sub(lastBlock);
            uint256 hippoReward = multiplier.mul(rewardPerBlock);
            h = hippoReward.mul(staked[account].stakedHIPPO).div(totalStakedAmount);
            staked[account].rewards = staked[account].rewards.add(h);
            staked[account].lastBlock = block.number;
        }

        _;
    }


    // Reward Updater LP
    modifier updateStakingRewardLP(address account) {

        uint256 h = 0;
        uint256 lastBlockLP = staked[account].lastBlockLP;
        if(block.number > staked[account].lastBlockLP && totalStakedAmountLP != 0) {
            uint256 multiplier = block.number.sub(lastBlockLP);
            uint256 hippoReward = multiplier.mul(rewardPerBlockLP);
            h = hippoReward.mul(staked[account].stakedHippoLP).div(totalStakedAmountLP);
            staked[account].rewardsLP = staked[account].rewardsLP.add(h);
            staked[account].lastBlockLP = block.number;
        }

        _;
    }



    function setHippoToken(address _addr) public onlyOwner {
        HippoToken = IERC20(address(_addr));
    }

    function setHippoLPToken(address _addr) public onlyOwner {
        HippoLPToken = IERC20(address(_addr));
    }


    // Set Rewards both
    function setRewardPerBlockBoth(uint256 _hippo, uint256 _lp) public onlyOwner {
        rewardPerBlock = _hippo;
        rewardPerBlockLP = _lp;
    }

    // Set Reward Per Block
    function setRewardPerBlock(uint256 _amount) public onlyOwner {
        rewardPerBlock = _amount;
    }

    // Set Reward Per Block - LP
    function setRewardPerBlockLP(uint256 _amount) public onlyOwner {
        rewardPerBlockLP = _amount;
    }

    // Set Reward
    function setDevAddress(address addr) public onlyOwner {
        devAddress = addr;
    }

    // Set Funding Contract
    function setFundAddress(address addr) public onlyOwner {
        fundAddress = addr;
    }


    // Stake $HIPPO
    function stake(uint256 amount) public updateStakingReward(_msgSender()) {
        require(isStart, "not started");
        require(0 < amount, ":stake: Fund Error");
        totalStakedAmount = totalStakedAmount.add(amount);
        staked[_msgSender()].stakedHIPPO = staked[_msgSender()].stakedHIPPO.add(amount);
        HippoToken.safeTransferFrom(_msgSender(), address(this), amount);
        staked[_msgSender()].lastBlock = block.number;
        emit Staked(_msgSender(), amount, totalStakedAmount);
    }

    // Unstake $HIPPO
    function unstake(uint256 amount) public updateStakingReward(_msgSender()) {
        require(isStart, "not started");
        require(amount <= staked[_msgSender()].stakedHIPPO, ":unstake: Fund ERROR");
        require(0 < amount, ":unstake: Fund Error 2");
        totalStakedAmount = totalStakedAmount.sub(amount);
        staked[_msgSender()].stakedHIPPO = staked[_msgSender()].stakedHIPPO.sub(amount);
        HippoToken.safeTransfer(_msgSender(), amount);
        staked[_msgSender()].lastBlock = block.number;
        emit Unstaked(_msgSender(), amount, totalStakedAmount);
    }

    // Claim
    function sendReward() public updateStakingReward(_msgSender()) {
        require(isStart, "not started");
        require(0 < staked[_msgSender()].rewards, "More than 0");
        uint256 reward = staked[_msgSender()].rewards;
        staked[_msgSender()].rewards = 0;
        uint256 totalWeight = rateReward.add(rateDevFee).add(rateFund);
        // 75% to User
        _mint(_msgSender(), reward.div(totalWeight).mul(rateReward));
        // 20% to Funding event
        _mint(fundAddress, reward.div(totalWeight).mul(rateFund));
        // 5% to DevFee
        _mint(devAddress, reward.div(totalWeight).mul(rateDevFee));
        emit Rewards(_msgSender(), reward);
    }

    // Stake $HIPPO/ETH
    function stakeLP(uint256 amount) public updateStakingRewardLP(_msgSender()) {
        require(isStart, "not started");
        require(0 < amount, ":stakeLP: Fund Error");
        totalStakedAmountLP = totalStakedAmountLP.add(amount);
        staked[_msgSender()].stakedHippoLP = staked[_msgSender()].stakedHippoLP.add(amount);
        HippoLPToken.safeTransferFrom(_msgSender(), address(this), amount);
        staked[_msgSender()].lastBlockLP = block.number;
        emit StakedLP(_msgSender(), amount, totalStakedAmount);
    }

    // Unstake $HIPPO/ETH
    function unstakeLP(uint256 amount) public updateStakingRewardLP(_msgSender()) {
        require(isStart, "not started");
        require(amount <= staked[_msgSender()].stakedHippoLP, ":unstakeLP: Fund ERROR, amount <= stakedHippo");
        require(0 < amount, ":unstakeLP: Fund Error 2");
        totalStakedAmountLP = totalStakedAmountLP.sub(amount);
        staked[_msgSender()].stakedHippoLP = staked[_msgSender()].stakedHippoLP.sub(amount);
        HippoLPToken.safeTransfer(_msgSender(), amount);
        staked[_msgSender()].lastBlockLP = block.number;
        emit UnstakedLP(_msgSender(), amount, totalStakedAmountLP);
    }    

    // Claim LP
    function sendRewardLP() public updateStakingRewardLP(_msgSender()) {
        require(isStart, "not started");
        require(0 < staked[_msgSender()].rewardsLP, "More than 0");
        uint256 reward = staked[_msgSender()].rewardsLP;
        staked[_msgSender()].rewardsLP = 0;
        uint256 totalWeight = rateReward.add(rateDevFee).add(rateFund);
        // 75% to User
        _mint(_msgSender(), reward.div(totalWeight).mul(rateReward));
        // 20% to Funding event
        _mint(fundAddress, reward.div(totalWeight).mul(rateFund));
        // 5% to DevFee
        _mint(devAddress, reward.div(totalWeight).mul(rateDevFee));
        emit Rewards(_msgSender(), reward);
    }

    function setStart() public onlyOwner {
        isStart = true;
    }

    // Get my reward
    function getHippoReward(address account) public view returns (uint256) {
        uint256 h = 0;
        uint256 lastBlock = staked[account].lastBlock;
        if(block.number > staked[account].lastBlock && totalStakedAmount != 0) {
            uint256 multiplier = block.number.sub(lastBlock);
            uint256 hippoReward = multiplier.mul(rewardPerBlock);
            h = hippoReward.mul(staked[account].stakedHIPPO).div(totalStakedAmount);
        }
        return staked[account].rewards.add(h);
    }

    function getHippoLPReward(address account) public view returns (uint256) {
        uint256 h = 0;
        uint256 lastBlock = staked[account].lastBlockLP;
        if(block.number > staked[account].lastBlockLP && totalStakedAmountLP != 0) {
            uint256 multiplier = block.number.sub(lastBlock);
            uint256 hippoReward = multiplier.mul(rewardPerBlockLP);
            h = hippoReward.mul(staked[account].stakedHippoLP).div(totalStakedAmountLP);
        }
        return staked[account].rewardsLP.add(h);
    }

    // Get staked amount of angry hippo
    function getStakedAmount(address _account) public view returns (uint256) {
        return staked[_account].stakedHIPPO;
    }
    
    // Get staked amount of angry hippo / eth
    function getStakedAmountOfLP(address _account) public view returns (uint256) {
        return staked[_account].stakedHippoLP;
    }

    // Get total staked aHIPPO
    function getTotalStakedAmount() public view returns (uint256) {
        return totalStakedAmount;
    }

    // Get total staked aHIPPO/ETH
    function getTotalStakedAmountLP() public view returns (uint256) {
        return totalStakedAmountLP;
    }
}