pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;


import "@openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin-solidity/contracts/math/SafeMath.sol";

interface FundInterface {
    
    function fund(address tokenAddress, address to, uint256 amount) external;
    function getBalance(address tokenAddress) external view returns (uint256);
}
contract HippoVoteExecutor {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    address owner;
    address voteAddr;
    address fundAddr;
    FundInterface fundContract;

    address  hippoAddr;
    IERC20 hippoContract;
    address  ahippoAddr;
    IERC20 ahippoContract;
    address dhippoAddr;
    IERC20 dhippoContract;

    
    modifier onlyOwner () {
        require(msg.sender == owner);
        _;
    }
    modifier  onlyVote () {
        require(msg.sender == voteAddr);
        _;
    }


    function setFundAddress(address _fundAddr) public {
        fundAddr  = _fundAddr;
        fundContract  = FundInterface(fundAddr);
    }
    function setVoteAddress(address _voteAddr) public {
        voteAddr = _voteAddr;
    }
    function setHippoAddress(address _hippoAddr) public {
        hippoAddr  = _hippoAddr;
        hippoContract = IERC20(hippoContract);
    }

    function setaHippoAddress(address _ahippoAddr) public {
        ahippoAddr  = _ahippoAddr;
        ahippoContract = IERC20(ahippoContract);
    }

    function setdHippoAddress(address _dhippoAddr) public {
        dhippoAddr  = _dhippoAddr;
        dhippoContract = IERC20(dhippoContract);
    }


    function fund(address tokenAddress, address to, uint amount) private {
        fundContract.fund(
            tokenAddress,
            to,
            amount
        );
    }

    function executeVote(string memory functionType, string memory functionName, address[] memory pAddr, uint256[] memory pInt, string[] memory pStr, bytes32[] memory pBytes)  public onlyVote {
        bytes memory _type = bytes(functionType);

        if(keccak256(_type) ==  keccak256("nothing"))  {
            //  do nothing
            return;
        }
        if(keccak256(_type) == keccak256("fund")) {
            executeFund(functionName, pAddr, pInt, pStr, pBytes);
        }
        if(keccak256(_type) == keccak256("hippo")) {

        }
        if(keccak256(_type) == keccak256("ahippo")) {

        }
        if(keccak256(_type) == keccak256("dhippo")) {

        }
    }

    function executeFund(string memory functionName, address[] memory pAddr, uint256[] memory pInt, string[] memory pStr, bytes32[] memory pBytes) private {
        bytes memory _name = bytes(functionName);
        if(keccak256(_name) == keccak256("investFund")) {
            fund(pAddr[0], pAddr[1], pInt[0]);
        }
        if(keccak256(_name) == keccak256("testcall")) {
            _testCall(pStr[0], pBytes[0]);
        }
        if(keccak256(_name) == keccak256("distFund")) {

        }
        if(keccak256(_name) == keccak256("burnFund")) {
            
        }
    }
    function _testCall(string memory pStr, bytes32 pBytes) public pure {
        keccak256(abi.encodePacked(pStr, pBytes));
    }
    function _executeIERC20() public{
        // need burn fund
    }
}