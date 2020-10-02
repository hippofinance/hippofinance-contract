pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FundWallet is Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function fund(address tokenAddress, address to, uint256 amount) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(to, amount);
    }

    function getBalance(address tokenAddress) public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

}