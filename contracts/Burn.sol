pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Executor.sol";
import "./FundWallet.sol";

contract Burn is VoteExecutor {

    address public aHIPPO;
    address public dHIPPO;
    address public fundAddr;

    constructor(address _aHIPPO, address _dHIPPO, address _fundAddr) public {
        aHIPPO = _aHIPPO;
        dHIPPO = _dHIPPO;
    }

    function setAHippo(address addr_) public onlyOwner {
        aHIPPO = addr_;
    }

    function setDHippo(address addr_) public onlyOwner {
        dHIPPO = addr_;
    }

    function executeVote() override public {
        FundWallet fundContract = FundWallet(fundAddr);
        ERC20 ahpo = ERC20(aHIPPO);
        ERC20 dhpo = ERC20(dHIPPO);
        uint256 aHippoBalance = ahpo.balanceOf(address(this));
        fundContract.fund(aHIPPO, address(0), aHippoBalance);
        uint256 dHippoBalance = dhpo.balanceOf(address(this));
        fundContract.fund(dHIPPO, address(0), dHippoBalance);
    }

}