
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

    address public hippoAddr;
    address public aHippoAddr;
    address public dHippoAddr;
    address public fundWalletAddr;

    uint256 public currentSeason;

    struct Option {
        string title;
        address suggester;
        address voteExecutor;
        uint256 countOfVote;
        uint256 executeType;
    }

    // constant
    uint256 EXECUTE_TYPE_EXECUTOR = 0;
    uint256 EXECUTE_TYPE_KEEP = 1;
    uint256 EXECUTE_TYPE_BURN = 2;
    uint256 EXECUTE_TYPE_DIST = 3;

    struct Voted {
        uint256 option;
        uint256 amount;
        bool isGetReward;
        uint256 vote;
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
        require(currentSeason == season, "onlyCurrentSeason");
        _;
    }
    modifier onlyRunningVote () {
        require(voteSeasons[currentSeason].startBlock <= block.number, "onlyRunningVote: Not Started");
        require(block.number <= voteSeasons[currentSeason].endBlock, "onlyRunningVote: Started");
        _;
    }
    modifier onlyEndVote () {
        require(voteSeasons[currentSeason].endBlock < block.number, "onlyEndVote");
        _;
    }
    modifier onlyVoteMember () {
        require(voteSeasons[currentSeason].voted[msg.sender].amount != 0, "onlyVoteMember");
        _;

    }
    modifier onlyNotVoteMember () {
        require(voteSeasons[currentSeason].voted[msg.sender].amount == 0, "You can vote only 1 option.");
        _;
    }

    constructor(address _hippo, address _aHippo, address _dHippo, address _fundWallet) public {
        hippoAddr = _hippo;
        aHippoAddr = _aHippo;
        dHippoAddr = _dHippo;
        fundWalletAddr = _fundWallet;
        currentSeason = 0;
    }

    function getCurrentSeason() public view returns(uint256 season) {
        return currentSeason;
    }

    function getOptions(uint256 season, uint256 id) public view returns(Option memory){
        return voteSeasons[season].options[id];
    }
    
    function getVoted(uint256 season, address addr) public view returns(Voted memory){
        return voteSeasons[season].voted[addr];
    }

    function addOption(string memory _title, address _executor) public onlyOwner {
        _addOptionInternal(_title, _executor, EXECUTE_TYPE_EXECUTOR);
    }

    function _addOptionInternal(string memory _title, address _executor, uint256 _executeType) internal onlyOwner {
        // title, suggester, executor, countOfVote, executeType
        Option memory _option = Option(_title, msg.sender, _executor, 0, _executeType);
        voteSeasons[currentSeason].options[voteSeasons[currentSeason].optionSize] = _option;
        voteSeasons[currentSeason].optionSize = voteSeasons[currentSeason].optionSize.add(1);
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

    function addDefaultOptions() public onlyOwner{
        addDoNothingOption();
        addBurnOption();
        addDistOption();
    }

    function addDoNothingOption() public onlyOwner{
        _addOptionInternal("Do nothing", address(0), EXECUTE_TYPE_KEEP);
    }

    function addBurnOption() public onlyOwner{
        _addOptionInternal("Burn all tokens", address(0), EXECUTE_TYPE_BURN);
    }

    function addDistOption() public onlyOwner{
        _addOptionInternal("Distribute all tokens", address(0), EXECUTE_TYPE_DIST);
    }

    function stake(uint256 optionId, uint256 amount) public onlyRunningVote onlyNotVoteMember {
        IERC20(hippoAddr).transferFrom(msg.sender, address(this), amount);
        voteSeasons[currentSeason].voted[msg.sender].option = optionId;
        voteSeasons[currentSeason].voted[msg.sender].amount = amount;
        voteSeasons[currentSeason].voted[msg.sender].vote = amount;
        voteSeasons[currentSeason].voted[msg.sender].isGetReward = false;
        voteSeasons[currentSeason].options[optionId].countOfVote = voteSeasons[currentSeason].options[optionId].countOfVote.add(amount);
        voteSeasons[currentSeason].totalVoted = voteSeasons[currentSeason].totalVoted.add(amount);
    }

    function unstake(uint256 seasonId) public {
        uint256 amount = voteSeasons[seasonId].voted[msg.sender].amount;
        IERC20(hippoAddr).transfer(msg.sender, amount);
        voteSeasons[seasonId].voted[msg.sender].amount = 0;
        uint256 optionId = voteSeasons[seasonId].voted[msg.sender].option;
        // If running
        if(voteSeasons[seasonId].startBlock <= block.number && block.number <= voteSeasons[seasonId].endBlock) {
            voteSeasons[seasonId].totalVoted = voteSeasons[seasonId].totalVoted.sub(amount);
            voteSeasons[seasonId].options[optionId].countOfVote = voteSeasons[seasonId].options[optionId].countOfVote.sub(amount);
            voteSeasons[seasonId].voted[msg.sender].vote = 0;
        }
    }

    function executeTopVoted() public onlyOwner{
        uint maxVoteId = 0;
        uint maxVoteSize = 0;
        for(uint i = 0; i < voteSeasons[currentSeason].optionSize; i++){
            if(voteSeasons[currentSeason].options[i].countOfVote > maxVoteSize){
                maxVoteSize = voteSeasons[currentSeason].options[i].countOfVote;
                maxVoteId = i ;
            }
        }
        executeOption(voteSeasons[currentSeason].options[maxVoteId]);
    }
    function executeOption(Option memory _option) internal onlyOwner {
        uint executeType = _option.executeType;
        if(executeType == EXECUTE_TYPE_EXECUTOR) {
            voteSeasons[currentSeason].isCustomer = true;
            VoteExecutor(_option.voteExecutor).executeVote();
            return;
        }
        if(executeType == EXECUTE_TYPE_KEEP) { 
            voteSeasons[currentSeason].isKeep = true;
            return;
        }
        if(executeType == EXECUTE_TYPE_BURN) { 
            voteSeasons[currentSeason].isBurn = true;
            FundWallet fundContract = FundWallet(fundWalletAddr);
            ERC20 ahpo = ERC20(aHippoAddr);
            ERC20 dhpo = ERC20(dHippoAddr);
            uint256 aHippoBalance = ahpo.balanceOf(fundWalletAddr);
            fundContract.fund(aHippoAddr, address(0x000000000000000000000000000000000000dEaD), voteSeasons[currentSeason].aBalance);
            uint256 dHippoBalance = dhpo.balanceOf(fundWalletAddr);
            fundContract.fund(dHippoAddr, address(0x000000000000000000000000000000000000dEaD), voteSeasons[currentSeason].dBalance);
            return;
        }
        if(executeType == EXECUTE_TYPE_DIST) {
            voteSeasons[currentSeason].isDistribute = true;
            return;
        }
    }
    
    function calcRewardAngryHippo(uint256 seasonId, address addr) public view returns(uint256) {
        uint256 totalVoteAmount = voteSeasons[currentSeason].totalVoted;
        uint256 myVoted = voteSeasons[currentSeason].voted[addr].vote;
        uint256 reward_ahpo = voteSeasons[currentSeason].aBalance.mul(myVoted).div(totalVoteAmount);
        if(voteSeasons[currentSeason].voted[msg.sender].isGetReward) {
            return 0;
        }
        return reward_ahpo;
    }

    function calcRewardDarkHippo(uint256 seasonId, address addr) public view returns(uint256) {
        uint256 totalVoteAmount = voteSeasons[currentSeason].totalVoted;
        uint256 myVoted = voteSeasons[currentSeason].voted[addr].vote;
        uint256 reward_dhpo = voteSeasons[currentSeason].dBalance.mul(myVoted).div(totalVoteAmount);
        if(voteSeasons[currentSeason].voted[msg.sender].isGetReward) {
            return 0;
        }
        return reward_dhpo;
    }

    function getReward() public onlyEndVote {
        uint256 season = currentSeason;
        require(voteSeasons[season].isDistribute, "It is not distributed");
        require(voteSeasons[season].voted[msg.sender].isGetReward == false, "::getReward:: Already rewarded");
        uint256 ahippo = calcRewardAngryHippo(season, msg.sender);
        uint256 dhippo = calcRewardDarkHippo(season, msg.sender);
        FundWallet fundContract = FundWallet(fundWalletAddr);
        fundContract.fund(aHippoAddr, msg.sender, ahippo);
        fundContract.fund(dHippoAddr, msg.sender, dhippo);
        voteSeasons[season].voted[msg.sender].isGetReward = true;
    }


    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public onlyOwner payable returns (bytes memory) {

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call.value(value)(callData);
        require(success, "Transaction execution reverted.");

        return returnData;
    }


}

