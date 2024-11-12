// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DEX {
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    using SafeMath for uint256;
    IERC20 token;

    event EthToTokenSwap(
        address swapper,
        string txDetails,
        uint256 ethInput,
        uint256 tokenOutput
    );

    event TokenToEthSwap(
        address swapper,
        string txDetails,
        uint256 tokensInput,
        uint256 ethOutput
    );

    event LiquidityProvided(
        address liquidityProvider,
        uint256 tokensInput,
        uint256 ethInput,
        uint256 liquidityMinted
    );

    event LiquidityRemoved(
        address liquidityRemover,
        uint256 tokensOutput,
        uint256 ethOutput,
        uint256 liquidityWithdrawn
    );

    constructor(address token_addr) {
        token = IERC20(token_addr);
    }

    function init(uint256 _tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX: init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(
            token.transferFrom(msg.sender, address(this), _tokens),
            "DEX: init - transfer did not transact"
        );
        return totalLiquidity;
    }

    function price(
        uint256 _xInput,
        uint256 _xReserves,
        uint256 _yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 _xInputWithFee = _xInput.mul(997);
        uint256 _numerator = _xInputWithFee.mul(_yReserves);
        uint256 _denominator = (_xReserves.mul(1000)).add(_xInputWithFee);
        return (_numerator / _denominator);
    }

    function getLiquidity(address _lp) public view returns (uint256) {
        return liquidity[_lp];
    }

    function ethToToken() public payable returns (uint256) {
        require(msg.value > 0, "cannot swap 0 ETH");
        uint256 _ethReserve = address(this).balance.sub(msg.value);
        uint256 _tokenReserve = token.balanceOf(address(this));
        uint256 _tokenOutput = price(msg.value, _ethReserve, _tokenReserve);

        require(
            token.transfer(msg.sender, _tokenOutput),
            "ethToToken(): reverted swap."
        );
        emit EthToTokenSwap(
            msg.sender,
            "Eth to Balloons",
            msg.value,
            _tokenOutput
        );
        return _tokenOutput;
    }

    function tokenToEth(uint256 _tokenInput) public returns (uint256) {
        require(_tokenInput > 0, "cannot swap 0 tokens");
        uint256 _tokenReserve = token.balanceOf(address(this));
        uint256 _ethOutput = price(
            _tokenInput,
            _tokenReserve,
            address(this).balance
        );
        require(
            token.transferFrom(msg.sender, address(this), _tokenInput),
            "tokenToEth(): reverted swap."
        );
        (bool _sent, ) = msg.sender.call{value: _ethOutput}("");
        require(_sent, "tokenToEth: revert in transferring eth to you!");
        emit TokenToEthSwap(
            msg.sender,
            "Balloons to ETH",
            _ethOutput,
            _tokenInput
        );
        return _ethOutput;
    }

    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "Must send value when depositing");
        uint256 _ethReserve = address(this).balance.sub(msg.value);
        uint256 _tokenReserve = token.balanceOf(address(this));
        uint256 _tokenDeposit;

        _tokenDeposit = (msg.value.mul(_tokenReserve) / _ethReserve).add(1);
        uint256 _liquidityMinted = msg.value.mul(totalLiquidity) / _ethReserve;
        liquidity[msg.sender] = liquidity[msg.sender].add(_liquidityMinted);
        totalLiquidity = totalLiquidity.add(_liquidityMinted);

        require(token.transferFrom(msg.sender, address(this), _tokenDeposit));
        emit LiquidityProvided(
            msg.sender,
            _liquidityMinted,
            msg.value,
            _tokenDeposit
        );
        return _tokenDeposit;
    }

    function withdraw(uint256 _amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {
        require(
            liquidity[msg.sender] >= _amount,
            "withdraw: sender does not have enough liquidity to withdraw."
        );
        uint256 _ethReserve = address(this).balance;
        uint256 _tokenReserve = token.balanceOf(address(this));
        uint256 _ethWithdrawn;

        _ethWithdrawn = _amount.mul(_ethReserve) / totalLiquidity;

        uint256 _tokenAmount = _amount.mul(_tokenReserve) / totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender].sub(_amount);
        totalLiquidity = totalLiquidity.sub(_amount);
        (bool _sent, ) = payable(msg.sender).call{value: _ethWithdrawn}("");
        require(_sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, _tokenAmount));
        emit LiquidityRemoved(msg.sender, _amount, _ethWithdrawn, _tokenAmount);
        return (_ethWithdrawn, _tokenAmount);
    }
}
