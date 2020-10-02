pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SwapWallet is Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 swappedAngryHippo;
    uint256 swappedDarkHippo;

    IERC20 aHippo;
    IERC20 aHippoV2;
    IERC20 dHippo;
    IERC20 dHippoV2;

    constructor(address _aHippo, address _aHippoV2, address _dHippo, address _dHippoV2) public {
        aHippo = IERC20(_aHippo);
        aHippoV2 = IERC20(_aHippoV2);
        dHippo = IERC20(_dHippo);
        dHippoV2 = IERC20(_dHippoV2);
        swappedAngryHippo = 0;
        swappedDarkHippo = 0;
    }

    function transfer(address token, uint256 amount) public onlyOwner {
        IERC20 token = IERC20(address(token));
        token.safeTransfer(msg.sender, amount);
    }

    function swapAngryHippo(uint256 amount) public {
        swappedAngryHippo = swappedAngryHippo.add(amount);
        aHippo.safeTransferFrom(msg.sender, address(this), amount);
        aHippoV2.safeTransfer(msg.sender, amount * 2);
    }

    function swapDarkHippo(uint256 amount) public {
        swappedDarkHippo = swappedDarkHippo.add(amount);
        dHippo.safeTransferFrom(msg.sender, address(this), amount);
        dHippoV2.safeTransfer(msg.sender, amount * 2);
    }

}