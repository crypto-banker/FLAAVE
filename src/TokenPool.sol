// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "./IFlashLoanRecipient.sol";
import "./IAToken_UndocumentedFunctions.sol";

contract TokenPool is ERC20Upgradeable, ReentrancyGuardUpgradeable {
    uint256 internal constant MAX_BIPS = 10000;
    uint16 internal constant REFERRAL_CODE = 0;

    IAToken public aToken;
    IPool public lendingPool;
    address public underlyingAsset;
    uint256 public flashLoanFeeBips;

    function initialize(IAToken _aToken, uint256 _flashLoanFeeBips) public initializer {
        aToken = _aToken;
        lendingPool = IAToken_UndocumentedFunctions(address(_aToken)).POOL();
        underlyingAsset = _aToken.UNDERLYING_ASSET_ADDRESS();
        flashLoanFeeBips = _flashLoanFeeBips;

        string memory name_ = string(abi.encodePacked(bytes("FLAAVE_"),IERC20MetadataUpgradeable(address(_aToken)).name()));
        string memory symbol_ = string(abi.encodePacked(bytes("FLAAVE_"),IERC20MetadataUpgradeable(address(_aToken)).symbol()));
        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();

        IERC20(underlyingAsset).approve(address(lendingPool), type(uint256).max);
    }

    function mintFromATokens(uint256 aTokensToDeposit) external nonReentrant {
        uint256 aTokenBalanceBefore = _aTokenBalance();
        require(aToken.transferFrom(msg.sender, address(this), aTokensToDeposit),
            "TokenPool.mintFromATokens: aToken transfer failed");
        uint256 aTokenBalanceIncrease = _aTokenBalance() - aTokenBalanceBefore;
        uint256 amountToMint = (aTokenBalanceIncrease * totalSupply()) / aTokenBalanceBefore;
        _mint(msg.sender, amountToMint);
    }

    function burnToATokens(uint256 flaaveTokensToBurn) external nonReentrant {
        uint256 aTokenBalanceBefore = _aTokenBalance();
        uint256 aTokensToSend = (aTokenBalanceBefore * flaaveTokensToBurn) / totalSupply();
        _burn(msg.sender, flaaveTokensToBurn);
        require(aToken.transfer(msg.sender, aTokensToSend),
            "TokenPool.burnToATokens: aToken transfer failed");
    }

    function mintFromUnderlying(uint256 underlyingToDeposit) external nonReentrant {
        uint256 aTokenBalanceBefore = _aTokenBalance();
        if (underlyingToDeposit != 0) {
            require(IERC20(underlyingAsset).transferFrom(msg.sender, address(this), underlyingToDeposit),
                "TokenPool.mintFromUnderlying: underlyingAsset transfer failed");            
        }
        uint256 underlyingTokenBalance = IERC20(underlyingAsset).balanceOf(address(this));
        lendingPool.supply(underlyingAsset, underlyingTokenBalance, address(this), REFERRAL_CODE);
        uint256 aTokenBalanceIncrease = _aTokenBalance() - aTokenBalanceBefore;
        uint256 amountToMint = (aTokenBalanceIncrease * totalSupply()) / aTokenBalanceBefore;
        _mint(msg.sender, amountToMint);
    }

    function burnToUnderlying(uint256 flaaveTokensToBurn) external nonReentrant {
        uint256 aTokenBalanceBefore = _aTokenBalance();
        uint256 tokensToSend = (aTokenBalanceBefore * flaaveTokensToBurn) / totalSupply();
        _burn(msg.sender, flaaveTokensToBurn);
        uint256 amountWithdrawn = lendingPool.withdraw(underlyingAsset, tokensToSend, msg.sender);
        require(amountWithdrawn == tokensToSend, "TokenPool.burnToUnderlying: amountWithdrawn != tokensToSend");
    }

    function flashLoan(uint256 loanSize, IFlashLoanRecipient flashLoanRecipient, bytes calldata params) external nonReentrant {
        uint256 aTokenBalanceBefore = _aTokenBalance();
        uint256 flashLoanFee = (loanSize * flashLoanFeeBips) / MAX_BIPS;

        uint256 amountWithdrawn = lendingPool.withdraw(underlyingAsset, loanSize, address(flashLoanRecipient));
        require(amountWithdrawn >= loanSize, "TokenPool.flashLoan: did not withdraw at least loan size");

        require(flashLoanRecipient.executeOperation(underlyingAsset, loanSize, flashLoanFee, msg.sender, params),
            "TokenPool.flashLoan: flashLoanRecipient.executeOperation failure");

        uint256 underlyingTokenBalance = IERC20(underlyingAsset).balanceOf(address(this));
        if (underlyingTokenBalance != 0) {
            lendingPool.supply(underlyingAsset, underlyingTokenBalance, address(this), REFERRAL_CODE);
        }

        uint256 aTokenBalanceAfter = _aTokenBalance();
        require(aTokenBalanceAfter >= aTokenBalanceBefore + flashLoanFee, "TokenPool.flashLoan: insufficient fee payment");
    }

    function _aTokenBalance() internal view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}
