// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract TokenSwapper {
    using SafeERC20 for IERC20;

    IWETH private weth;
    IUniswapV2Router02 private uniswapRouter;
    uint public wethAmount;

    event make_weth(address indexed _from, address indexed _to, uint[] _value);
    event WethValue(uint _Value);
    event AmountOut(uint[] Amountout);
    constructor(address _weth, address _uniswapRouter) {
        weth = IWETH(_weth);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function swapToWeth(address[] calldata tokens, uint256[] calldata amounts) public {
    require(tokens.length == amounts.length, "TokenSwapper: Invalid inputs");

    for (uint256 i = 0; i < tokens.length; i++) {
        if (tokens[i] == address(weth)) {
            wethAmount += amounts[i];
            continue;
        }

        address[] memory path = new address[](2);
        path[0] = tokens[i];
        path[1] = address(weth);

        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(amounts[i], path);
        require(amountsOut[0] > 0, "TokenSwapper: Invalid swap");


        // Transfer tokens from the user's wallet to the contract address

        IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
        // Approve the transfer of tokens to Uniswap Router
        IERC20(tokens[i]).approve(address(uniswapRouter), amounts[i]);
        // Check allowance
        uint allowance = IERC20(tokens[i]).allowance(msg.sender, address(this));
        require(allowance >= amounts[i], "TokenSwapper: Insufficient allowance");

        // Swap tokens for WETH
        uniswapRouter.swapExactTokensForTokens(
            amounts[i],
            amountsOut[0],
            path,
            address(this),
            block.timestamp
        );

        wethAmount += amountsOut[0];
        emit make_weth(path[0], path[1], amountsOut);
    }

    emit WethValue(wethAmount);
}



    


    function swapWethToTokens(address[] calldata inputTokens,address[] calldata outputTokens,uint[] calldata inputAmounts, uint[] calldata pecentageAmounts) external payable {
        require(outputTokens.length == pecentageAmounts.length, "Invalid input");
        wethAmount=0;

        weth.deposit{value: msg.value}();
        wethAmount+=msg.value;

        swapToWeth(inputTokens,inputAmounts);
        // Approve the Uniswap router to spend WETH tokens
        weth.approve(address(uniswapRouter), wethAmount);
        
        // Path for the WETH to token swaps
        address[] memory path = new address[](2);
        path[0] = address(weth);
        
        // Loop through all the tokens to be swapped
        for (uint i = 0; i < outputTokens.length; i++) {
            if(outputTokens[i]==address(weth)){
                continue;
            }
            path[1] = outputTokens[i];
            uint256[] memory amountsout = uniswapRouter.getAmountsOut(wethAmount*pecentageAmounts[i]/100, path);
            require(amountsout[1] > 0, "TokenSwapper: Invalid swap");
            
            // Execute the swap
            uniswapRouter.swapExactTokensForTokens(
                wethAmount*pecentageAmounts[i]/100,
                amountsout[1],
                path,
                address(this),
                block.timestamp
            );
            emit make_weth(path[0],path[1],amountsout);
        }
    }


}
