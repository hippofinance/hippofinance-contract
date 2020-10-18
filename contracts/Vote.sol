
pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "@penzeppelin-solidity/contracts/math/SafeMath.sol";
import "./voteExecutor.sol";


contract HippoVote {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public owner;
    address public executor;
    HippoVoteExecutor public executorContract;
    uint256 public totalVoteAmount;
    uint256 public startBlock;
    uint256 public endBlock;

    bool public isDistribute;

    uint256 public abalance;
    uint256 public dbalance;
    
    // This vote contract is owner of fundWallet
    address public fundAddr;
    address public dhippoAddr;
    address public ahippoAddr;
    address public hippoContractAddress;
    IERC20 public dhippoContract;
    IERC20 public ahippoContract;
    IERC20 public hippoContract;

    IERC20 public fundContract;
    mapping(address=>uint256) public ahippoRewards;
    mapping(address=>uint256) public dhippoRewards;
    
    uint256 public votingPeriodLength = 300;
    uint256 public costPerVote = 1000000000000000000;
    uint256 public hippoCost = 100000000000000000; // 0.1 hippo
    uint16 public bidId;
    uint16 public topBidId;
    
    struct bid {
        uint16 bidId;
        uint16 chainSize;
        uint16 bidType;
        uint256 votes;
        string title;
        mapping(uint=>bidChain) chain;
    } // bidType 0 => call to executor
    //bidType 1 => local call

    mapping(address => bool) public isGetReward;

    struct  bidUI {
        uint16 bidId;
        uint256 votes;
        string  title;
    }
    mapping(uint16 => bid) public currentBids;
    struct bidChain {
        string functionType;
        string functionName;
        address[] pAddr;
        uint256[] pInt;
        string[] pStr;
        bytes32[] pBytes;
    }
    mapping(address => uint256) public votedHippo;
    address[] votedHippoOwner;
    
    uint256 public lastBlock;
    uint256 public currentEndBlock;
    modifier onlyOwner () {
        require(msg.sender == owner);
        _;
    }
    modifier onlyExecutor () {
        require(msg.sender == executor);
        _;
    }
    
    constructor () public {
        // bidId == 0: for Invalid Bid
        isDistribute = false;
        bidId = 1;
        topBidId = 1;
        owner = address(msg.sender);
        startBlock = block.number;
        endBlock = startBlock + votingPeriodLength;
        totalVoteAmount = 0;
    }

    function setVotingPeriodLength(uint256 _length) public onlyOwner {
        votingPeriodLength = _length;
        endBlock = startBlock + votingPeriodLength;
    }

    function setExecutor (address _executor) public onlyOwner {
        executor = _executor;
        executorContract = HippoVoteExecutor(executor);
    }

    function setHippoAddress(address _address) public onlyOwner{
        hippoContractAddress = _address;
        hippoContract = IERC20(address(hippoContractAddress));
    }

    function proposeBid(
        string memory title,
        string memory functionType, 
        string memory functionName, 
        uint16 bidType,
        address[] memory pAddr,
        uint256[] memory pInt,
        string[] memory pStr,
        bytes32[] memory pBytes
    ) onlyOwner public {

        bid memory _bid = bid(bidId, 0, bidType, 0, title);
        currentBids[bidId] = _bid;
        addChain(bidId, functionType, functionName, pAddr, pInt,  pStr, pBytes);
        // if(getTopBid().votes == 0) {
        //     topBidId =  bidId;
        // } topbid  will be first bid at first

        bidId = bidId + 1;

        // do not remove bid for ensure topBidId
        // to remove bid, just create new contract
    }
    
    function addChain (
        uint16 _bidId,
        string memory functionType, 
        string memory functionName, 
        address[] memory pAddr,
        uint256[] memory pInt,
        string[] memory pStr,
        bytes32[] memory pBytes
    ) onlyOwner public {
        bid storage _bid = currentBids[_bidId];
        bidChain memory c = _createChain(
                functionType, functionName, pAddr, pInt, pStr, pBytes
                );
        _bid.chain[_bid.chainSize] = c;
        _bid.chainSize = _bid.chainSize + 1;
    }

    // THIS IS FOR NEXT VERSION
    // function unVote(uint16 _bidId, uint256 amount) private { // DO NOT SUPPORT FOR NOW!!
    //     require(_bidId > 0);
    //     require(_bidId < bidId);
    //     require(votedHippo[msg.sender] >= amount);
    //     bool deleted = false;
    //     for(uint i = 0; i < votedHippoOwner.length; i++){
    //         if(votedHippoOwner[i] == msg.sender){
    //             votedHippoOwner[i] = address(0);
    //             deleted = true;
    //             break;
    //         }
    //     }
    //     require(deleted);
    //     votedHippo[msg.sender] -= amount;
    //     hippoContract.safeTransfer(msg.sender, amount);
    // }

    // Check someone voted or not
    function isVoted(address sender) public view returns(bool) {
        return votedHippo[sender] > 0;
    }

    // Check voting is end or not
    function isValidVote() public view returns(bool) {
        return block.number <= endBlock;
    }
    
    // get Array Size
    function getVoteCount() public view returns(uint) {
        uint arraySize  = 0;
        for(uint16 i = 1; i < bidId; i++){
            if(currentBids[i].bidId  != 0) arraySize  +=  1;
        }
        return arraySize;
    }

    function getVoteItems(uint arraySize) public view  returns(bidUI[] memory) {
        bidUI[] memory ret = new bidUI[](arraySize);
        uint arrayIndex = 0;
        for(uint16 i = 1; i < bidId; i++){ // because it starts from 1
            if(currentBids[i].bidId != 0){
                ret[arrayIndex++] = bidUI(currentBids[i].bidId, currentBids[i].votes,  currentBids[i].title);
            }
        }
        return ret;
    }

    function getTopBid() private returns(bid storage) {
        return  getBidFromId(topBidId);
    }

    function getBidFromId(uint16 _bidId) private returns(bid storage) {
        for(uint16 i = 1; i < bidId; i++){ // because it starts from 1
            if(currentBids[i].bidId == _bidId){
                return currentBids[i];
            }
        }
        require(currentBids[0].bidId != 0);
        return currentBids[0]; // None
   }

    function vote(uint16 _bidId, uint256 amount) public {
        require(_bidId > 0);
        require(_bidId < bidId);
        _vote(msg.sender,  getBidFromId(_bidId), amount);
    }

    function  _vote(address sender, bid storage _bid, uint256 amount) private {
        require(!isVoted(sender));
        require(_bid.bidId > 0);
        uint allowanceAmount = hippoContract.allowance(sender, address(this));
        require(allowanceAmount >= amount);

        _bid.votes = _bid.votes.add(amount);
        bid storage _topBid = getTopBid();
        votedHippo[sender] = votedHippo[sender].add(amount);
        votedHippoOwner.push(sender);
        if(_bid.votes > _topBid.votes)  {
            topBidId = _bid.bidId;
        }

        totalVoteAmount = totalVoteAmount.add(amount);

        hippoContract.safeTransferFrom(sender, address(this), amount);
    }

    function voteTop(uint256 amount) public {
        vote(topBidId, amount);
    }

    function executeVote() public onlyOwner{
        require(isValidVote());
        bid storage _executeBid = getTopBid();
        mapping(uint => bidChain) storage chain  = _executeBid.chain;

        require(_executeBid.votes > 0);
        

        for(uint i = 0; i < votedHippoOwner.length; i++){
            address voter = votedHippoOwner[i];
            if(voter == address(0)) continue;
            uint amount = votedHippo[voter];
            hippoContract.safeApprove(voter, amount);
        }
        
        if(_executeBid.bidType == 0) {
            for(uint i = 0; i < _executeBid.chainSize; i++) {
                _executeChain(chain[i]);
            }
        }
        if(_executeBid.bidType == 1) {
            _executeLocalBid();
        }
    }

    function unstake() public {
        require(votedHippo[msg.sender] > 0);
        if(isValidVote()) {
            // Unvote
        }
        // hippoContract.safeApprove(msg.sender, votedHippo[msg.sender]);
        hippoContract.safeTransfer(msg.sender, votedHippo[msg.sender]);
        totalVoteAmount = totalVoteAmount.sub(votedHippo[msg.sender]);
        votedHippo[msg.sender] = 0;
    }

    function _executeLocalBid() internal {
        bid storage _topBid =   getTopBid();
        for(uint i = 0; i < _topBid.chainSize; i++) {
            _executeLocalChain(_topBid.chain[i]);
        }
    }

    function addDefaultOptions(uint256 bits) public onlyOwner{
        addNothingToVote();
        if(bits & 0x1 != 0) {
            addBurnFundToVote();
        }
        if(bits & 0x2 != 0) {
            addDistributeFundToVote();
        }
        // and so on..
    }
    function addDistributeFundToVote() public onlyOwner {
        //shortcut to add bid and add chain
        proposeBid("distribute all coin in fund", "fund", "dist", 1, new address[](0), new uint256[](0), new string[](0), new bytes32[](0));
    }
    function addBurnFundToVote()  public onlyOwner {
        //shortcut to burn fund
        proposeBid("burn all coin in fund", "fund", "burn", 1, new address[](0), new uint256[](0), new string[](0), new bytes32[](0));
    }
    function addNothingToVote()  public onlyOwner {
        //shortcut to nothing
        proposeBid("do nothing", "nothing", "nothing", 1, new address[](0), new uint256[](0), new string[](0), new bytes32[](0));
    }
    function _distributeFund() internal {
        abalance = ahippoContract.balanceOf(fundAddr);
        dbalance = dhippoContract.balanceOf(fundAddr);
        isDistribute = true;
        // uint256 totalVoteAmount = 0;
        // for(uint i = 0; i  < votedHippoOwner.length; i++){
        //     address voter  = votedHippoOwner[i];
        //     if(voter == address(0)) continue;
        //     uint amount = votedHippo[voter];
        //     totalVoteAmount =  totalVoteAmount.add(amount);
        // }
        // uint256 abalance = ahippoContract.balanceOf(fundAddr);
        // uint256 dbalance = dhippoContract.balanceOf(fundAddr);

        // for(uint i = 0; i  < votedHippoOwner.length; i++){
        //     address voter = votedHippoOwner[i];
        //     if(voter == address(0)) continue;
        //     uint256 voted = votedHippo[voter];
        //     ahippoRewards[voter] = abalance.div(totalVoteAmount).mul();
        //     dhippoRewards[voter] = dbalance.div(totalVoteAmount).mul();
        //     // uint ratio = amount.mul(abalance);
        //     // uint tokens = ratio.div(totalVoteAmount);
        //     // //fundContract.fund(ahippoAddr, voter, amount);

        //     // ratio = amount.mul(dbalance);
        //     // tokens = ratio.div(totalVoteAmount);
        //     // //fundContract.fund(dhippoAddr, voter, amount);

        //     // votedHippo[voter] = 0; // dont send anymore for unvote
        // }
    }

    function getReward() public {
        require(isGetReward[msg.sender] == false, "Already rewarded");

        // uint256 totalVoteAmount = 0;
        // for(uint i = 0; i  < votedHippoOwner.length; i++){
        //     address voter  = votedHippoOwner[i];
        //     if(voter == address(0)) continue;
        //     uint amount = votedHippo[voter];
        //     totalVoteAmount =  totalVoteAmount.add(amount);
        // }

        // uint256 abalance = ahippoContract.balanceOf(fundAddr);
        // uint256 dbalance = dhippoContract.balanceOf(fundAddr);

        uint256 reward_ahpo = abalance.div(totalVoteAmount).mul(votedHippo[msg.sender]);
        uint256 reward_dhpo = dbalance.div(totalVoteAmount).mul(votedHippo[msg.sender]);

        // This contract is owner of fundWallet
        fundContract.fund(ahippoAddr, msg.sender, reward_ahpo);
        fundContract.fund(dhippoAddr, msg.sender, reward_dhpo);

        isGetReward[msg.sender] = true;
        

        // for(uint i = 0; i  < votedHippoOwner.length; i++){
        //     address voter = votedHippoOwner[i];
        //     if(voter == address(0)) continue;
        //     uint256 voted = votedHippo[voter];
        //     ahippoRewards[voter] = abalance.div(totalVoteAmount).mul();
        //     dhippoRewards[voter] = dbalance.div(totalVoteAmount).mul();
        //     // uint ratio = amount.mul(abalance);
        //     // uint tokens = ratio.div(totalVoteAmount);
        //     // //fundContract.fund(ahippoAddr, voter, amount);

        //     // ratio = amount.mul(dbalance);
        //     // tokens = ratio.div(totalVoteAmount);
        //     // //fundContract.fund(dhippoAddr, voter, amount);

        //     // votedHippo[voter] = 0; // dont send anymore for unvote
        // }
    }
    
    function _executeLocalChain(bidChain memory  chain) internal {
        bytes memory _type = bytes(chain.functionType);
        bytes memory _name = bytes(chain.functionName);
        if(keccak256(_type) == keccak256("fund")) {
            if(keccak256(_name) == keccak256("dist")) {
                _distributeFund();
            }
            if(keccak256(_name) == keccak256("burn")) {
                uint256 aHippoBalance = ahippoContract.balance(address(fundAddr));
                fundContract.fund(ahippoAddr, address(0), aHippoBalance);
                uint256 dHippoBalance = dhippoContract.balance(address(fundAddr));
                fundContract.fund(dhippoAddr, address(0), dHippoBalance);
            }
        }
        if(keccak256(_type) == keccak256("nothing")) {
            // nothing
            return;
        }
    }
    function _executeChain(bidChain memory chain) internal {
        executorContract.executeVote(
            chain.functionType,
            chain.functionName,
            chain.pAddr,
            chain.pInt,
            chain.pStr,
            chain.pBytes
        );
    }
    
    function _createChain(
        string memory _functionType,
        string memory _functionName, 
        address[] memory _pAddr,
        uint256[] memory _pInt,
        string[] memory _pStr,
        bytes32[] memory _pBytes) internal pure returns(bidChain memory) {
            bidChain memory ret = bidChain(_functionType, _functionName, _pAddr, _pInt, _pStr, _pBytes);
            return ret;
    }
}

