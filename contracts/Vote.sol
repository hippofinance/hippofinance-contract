
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Executor.sol";
import "./FundWallet.sol";
contract HippoVote is Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address aHippoAddr;
    address dHippoAddr;
    address hippoAddr;
    address fundWalletAddr;

    uint256 currentSeason;

    struct Option {
        string title;
        address suggester;
        address voteExecutor;
        uint256 countOfVote;
        uint256 executeType;

    }
    uint EXECUTE_TYPE_EXECUTOR = 0;
    uint EXECUTE_TYPE_KEEP = 1;
    uint EXECUTE_TYPE_BURN = 2;
    uint EXECUTE_TYPE_DIST = 3;

    struct Voted {
        uint256 option;
        uint256 amount;
        bool isGetReward;
    }

    struct VoteSeason {
        uint256 startBlock; // Start Block
        uint256 endBlock;   // End Block
        uint256 optionSize;     // MaxBid
        uint256 totalVoted; // Totalvoted;
        uint256 aBalance;   // aHippo balance
        uint256 dBalance;   // dHippo balance
        uint256 leftAhippoBalance; // aHippo balance
        uint256 leftDhippoBalance; // dHippo balance
        bool isDistribute;
        bool isKeep;
        bool isBurn;
        bool isCustomer;
        mapping (address => Voted) voted;
        mapping (uint256 => Option) options;

    }

    mapping (uint256 => VoteSeason) public voteSeasons;

    modifier onlyCurrentSeason (uint256 season) {
        require(currentSeason == season);
        _;
    }
    modifier onlyRunningVote () {
        require(voteSeasons[currentSeason].endBlock <= block.number);
        _;
    }
    modifier onlyEndVote () {
        require(block.number < voteSeasons[currentSeason].endBlock);
        _;
    }
    modifier onlyVoteMember () {
        require(getCurrentSeason().voted[msg.sender].amount != 0);
        _;

    }
    modifier onlyNotVoteMember () {
        require(getCurrentSeason().voted[msg.sender].amount == 0);
        _;
    }
    function getCurrentSeason() internal {
        return voteSeasons[currentSeason];
    }
    function getOptions(uint256 season) public returns(mapping(uint256=>Option) memory){
        return voteSeasons[season].options;
    }
    function addOption(string memory _title, address _executor) public onlyRunningVote onlyOwner {
        _addOptionInternal(_title, _executor, EXECUTE_TYPE_EXECUTOR);
    }
    function _addOptionInternal(string memory _title, address _executor, uint256 _executeType) internal onlyRunningVote {
        Option memory _option = Option(_title, msg.sender, _executor, 0, _executeType);
        VoteSeason storage season = getCurrentSeason();
        season.options[season.optionSize] = _option;
        season.optionSize = season.optionSize.add(1);

    }

    function newSeason(uint256 startBlock, uint256 endBlock) public onlyOwner {
        require(voteSeasons[currentSeason].endBlock < block.number, "You can start after end this season");
        currentSeason = currentSeason + 1;
        voteSeasons[currentSeason].startBlock = startBlock;
        voteSeasons[currentSeason].endBlock   = endBlock;
        voteSeasons[currentSeason].optionSize     = 0;
        voteSeasons[currentSeason].totalVoted = 0;
        voteSeasons[currentSeason].aBalance   = IERC20(aHippoAddr).balanceOf(fundWalletAddr);
        voteSeasons[currentSeason].dBalance   = IERC20(dHippoAddr).balanceOf(fundWalletAddr);
        voteSeasons[currentSeason].leftAhippoBalance = IERC20(aHippoAddr).balanceOf(fundWalletAddr);
        voteSeasons[currentSeason].leftDhippoBalance = IERC20(dHippoAddr).balanceOf(fundWalletAddr);
        voteSeasons[currentSeason].isDistribute = false;
        voteSeasons[currentSeason].isKeep       = false;
        voteSeasons[currentSeason].isBurn       = false;
        voteSeasons[currentSeason].isCustomer   = false;
    }

    function addDefaultOptions(uint256 bits) public onlyOwner{
        addOption("do nothing", address(0));
        if(bits & 1) {
            _addOptionInternal("burn all tokens", address(0), EXECUTE_TYPE_BURN);
        }
        if(bits & 2){
            _addOptionInternal("distribute all tokens", address(0), EXECUTE_TYPE_DIST);
        }
    }

    function stake(uint256 optionId, uint256 amount) public onlyRunningVote onlyNotVoteMember{
        require(IERC20(hippoAddr).allowance(address(this), msg.sender) >= amount, "not approved");
        IERC20(hippoAddr).transferFrom(msg.sender, address(this), amount);
        getCurrentSeason().voted[msg.sender].option = optionId;
        getCurrentSeason().voted[msg.sender].amount = amount;
        getCurrentSeason().voted[msg.sender].isGetReward = false;
        getCurrentSeason().options[optionId].countOfVote = getCurrentSeason().options[optionId].countOfVote.add(amount);
        getCurrentSeason().totalVoted = getCurrentSeason().totalVoted.add(amount);
    }

    function unstake(uint256 seasonId) public {
        uint256 amount = voteSeasons[seasonId].voted[msg.sender].amount;
        IERC20(hippoAddr).transfer(msg.sender, amount);
        voteSeasons[seasonId].voted[msg.sender].amount = 0;
        uint256 optionId = voteSeasons[seasonId].voted[msg.sender].option;
        if(seasonId == currentSeason) {
            voteSeasons[seasonId].options[optionId].countOfVote = voteSeasons[seasonId].options[optionId].countOfVote.sub(amount);
        }
    }

    function executeTopVoted() public onlyOwner{
        uint maxVoteId = 0;
        uint maxVoteSize = 0;
        for(uint i = 0; i < getCurrentSeason().optionSize; i++){
            if(getCurrentSeason().options[i].countOfVote > maxVoteSize){
                maxVoteSize = getCurrentSeason().options[i].countOfVote;
                maxVoteId = i ;
            }
        }
        executeOption(getCurrentSeason().options[maxVoteId]);
    }
    function executeOption(Option memory _option) private {
        uint executeType = _option.executeType;
        if(executeType == EXECUTE_TYPE_EXECUTOR) {
            getCurrentSeason().isCustomer = true;
            VoteExecutor(_option.voteExecutor).executeVote();
        }
        if(executeType == EXECUTE_TYPE_KEEP) { 
            getCurrentSeason().isKeep = true;
            // do nothing
        }
        if(executeType == EXECUTE_TYPE_BURN) { 
            getCurrentSeason().isBurn = true;
            VoteExecutor(_option.voteExecutor).executeVote();
        }
        if(executeType == EXECUTE_TYPE_DIST) {
            getCurrentSeason().isDistribute = true;
        }
    }
    
    function calcRewardAngryHippo(uint256 seasonId, address addr) public view returns(uint256) {
        uint256 totalVoteAmount = getCurrentSeason().totalVoted;
        uint256 myVoted = getCurrentSeason().voted[addr].amount;
        uint256 reward_ahpo = getCurrentSeason().aBalance.mul(myVoted).div(totalVoteAmount);
        return reward_ahpo;
    }

    function calcRewardDarkHippo(uint256 seasonId, address addr) public view returns(uint256) {
        uint256 totalVoteAmount = getCurrentSeason().totalVoted;
        uint256 myVoted = getCurrentSeason().voted[addr].amount;
        uint256 reward_dhpo = getCurrentSeason().dBalance.mul(myVoted).div(totalVoteAmount);
        return reward_dhpo;
    }

    function getReward() public onlyEndVote {
        uint256 season = currentSeason;
        require(voteSeasons[season].isDistribute, "It is not distributed");
        require(voteSeasons[season].Voted[msg.sender].isGetReward == false, "::getReward:: Already rewarded");
        uint256 ahippo = calcRewardAngryHippo(season, msg.sender);
        uint256 dhippo = calcRewardDarkHippo(season, msg.sender);
        FundWallet fundContract = FundWallet(fundWalletAddr);
        fundContract.fund(aHippoAddr, msg.sender, ahippo);
        fundContract.fund(dHippoAddr, msg.sender, dhippo);
        voteSeasons[season].Voted[msg.sender].isGetReward = true;
    }

}

