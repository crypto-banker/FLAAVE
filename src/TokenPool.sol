// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "lib/aave-v3-core/contracts/interfaces/IAToken.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC3156Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "./IAToken_UndocumentedFunctions.sol";

contract TokenPool is ERC20Upgradeable, ReentrancyGuardUpgradeable, IERC3156FlashLenderUpgradeable {
    uint256 internal constant MAX_BIPS = 10000;
    uint16 internal constant REFERRAL_CODE = 0;

    IAToken public aToken;
    IPool public lendingPool;
    address public underlyingToken;
    uint256 public flashLoanFeeBips;

    /// @notice emitted upon the successful execution of a flash loan
    event FlashLoanExecuted(uint256 amount, uint256 fee);

    function initialize(IAToken _aToken, uint256 _flashLoanFeeBips) public initializer {
        aToken = _aToken;
        lendingPool = IAToken_UndocumentedFunctions(address(_aToken)).POOL();
        underlyingToken = _aToken.UNDERLYING_ASSET_ADDRESS();
        flashLoanFeeBips = _flashLoanFeeBips;

        string memory name_ = string(abi.encodePacked(bytes("FLAAVE_"),IERC20MetadataUpgradeable(address(_aToken)).name()));
        string memory symbol_ = string(abi.encodePacked(bytes("FLAAVE_"),IERC20MetadataUpgradeable(address(_aToken)).symbol()));
        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();

        IERC20(underlyingToken).approve(address(lendingPool), type(uint256).max);
    }

    /**
     * @notice Mint FLAAVE tokens by providing aTokens
     * @param aTokensToDeposit amount of aTokens to be converted into FLAAVE tokens
     * @dev The caller must first approve this contract to transfer aTokens on their behalf
     */
    function mintFromATokens(uint256 aTokensToDeposit) external nonReentrant {
        // ensure that aToken balance is checked first, in case it has changed due to rebasing
        uint256 aTokenBalanceBefore = _aTokenBalance();

        // pull the aTokens from the caller
        require(aToken.transferFrom(msg.sender, address(this), aTokensToDeposit),
            "TokenPool.mintFromATokens: aToken transfer failed");

        // calculate mint amount and perform mint
        uint256 aTokenBalanceIncrease = _aTokenBalance() - aTokenBalanceBefore;
        uint256 amountToMint = (aTokenBalanceIncrease * totalSupply()) / aTokenBalanceBefore;
        _mint(msg.sender, amountToMint);
    }


    /**
     * @notice Burn FLAAVE tokens in exchange for aTokens
     * @param flaaveTokensToBurn amount of FLAAVE tokens to be converted into aTokens
     */
    function burnToATokens(uint256 flaaveTokensToBurn) external nonReentrant {
        // ensure that aToken balance is checked first, in case it has changed due to rebasing
        uint256 aTokenBalanceBefore = _aTokenBalance();

        // calculate the burn conversion amount, burn the FLAAVE tokens, and perform the transfer
        uint256 aTokensToSend = (aTokenBalanceBefore * flaaveTokensToBurn) / totalSupply();
        _burn(msg.sender, flaaveTokensToBurn);
        require(aToken.transfer(msg.sender, aTokensToSend),
            "TokenPool.burnToATokens: aToken transfer failed");
    }

    /**
     * @notice Mint FLAAVE tokens by providing underlyingToken
     * @param underlyingToDeposit amount of underlyingToken to be converted into FLAAVE tokens
     * @dev The caller must first *either* approve this contract to transfer underlyingToken on their behalf, *or* be a contract and transfer
     * `underlyingToken` directly to this contract before invoking this function (in which case `underlyingToDeposit` should be set to '0')
     */
    function mintFromUnderlying(uint256 underlyingToDeposit) external nonReentrant {
        // ensure that aToken balance is checked first, in case it has changed due to rebasing
        uint256 aTokenBalanceBefore = _aTokenBalance();

        // pull the specified amount of underlyingTokens from the caller
        if (underlyingToDeposit != 0) {
            require(IERC20(underlyingToken).transferFrom(msg.sender, address(this), underlyingToDeposit),
                "TokenPool.mintFromUnderlying: underlyingToken transfer failed");            
        }

        // supply all available underlyingToken balance to AAVE in exchange for new aTokens
        uint256 underlyingTokenBalance = IERC20(underlyingToken).balanceOf(address(this));
        lendingPool.supply(underlyingToken, underlyingTokenBalance, address(this), REFERRAL_CODE);

        // calculate mint amount and perform mint
        uint256 aTokenBalanceIncrease = _aTokenBalance() - aTokenBalanceBefore;
        uint256 amountToMint = (aTokenBalanceIncrease * totalSupply()) / aTokenBalanceBefore;
        _mint(msg.sender, amountToMint);
    }

    /**
     * @notice Burn FLAAVE tokens in exchange for underlyingTokens
     * @param flaaveTokensToBurn amount of FLAAVE tokens to be converted into underlyingTokens
     */
    function burnToUnderlying(uint256 flaaveTokensToBurn) external nonReentrant {
        // ensure that aToken balance is checked first, in case it has changed due to rebasing
        uint256 aTokenBalanceBefore = _aTokenBalance();

        // calculate the burn conversion amount, burn the FLAAVE tokens, and perform the transfer by 'withdrawing' from AAVE
        uint256 tokensToSend = (aTokenBalanceBefore * flaaveTokensToBurn) / totalSupply();
        _burn(msg.sender, flaaveTokensToBurn);
        uint256 amountWithdrawn = lendingPool.withdraw(underlyingToken, tokensToSend, msg.sender);
        // verify that the correct amount was withdrawn
        require(amountWithdrawn == tokensToSend, "TokenPool.burnToUnderlying: amountWithdrawn != tokensToSend");
    }

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @dev This contract only supports flashLoans taken in `aToken` or `underlyingToken`.
     * Loans can also be returned in either token or a mix of the two; any `underlyingToken` provided to this contract as a result of the `receiver.onFlashLoan`
     * call will be converted into aTokens automatically, to help cover the flashLoan
     */
    function flashLoan(IERC3156FlashBorrowerUpgradeable receiver, address token, uint256 amount, bytes calldata data) external nonReentrant returns (bool) {
        // ensure that aToken balance is checked first, in case it has changed due to rebasing
        uint256 aTokenBalanceBefore = _aTokenBalance();

        // simple fee calculated using Basis Points ('BIPS')
        uint256 flashLoanFee = (amount * flashLoanFeeBips) / MAX_BIPS;

        // if caller desires underlyingTokens, withdraw it from AAVE to the specified `receiver`
        if (token == underlyingToken) {
            uint256 amountWithdrawn = lendingPool.withdraw(underlyingToken, amount, address(receiver));
            require(amountWithdrawn >= amount, "TokenPool.flashLoan: did not withdraw at least loan size");
        // if the caller desires aTokens, transfer them directly to the specified `receiver`
        } else if (token == address(aToken)) {
            require(aToken.transfer(address(receiver), amount), "TokenPool.flashLoan: aToken transfer failed");
        // otherwise, revert, since this contract only supports flashLoans taken in `aToken` or `underlyingToken`
        } else {
            revert("TokenPool.flashLoan: invalid token specified");
        }

        // ERC-3156 requires that the provided IERC3156FlashBorrower return `keccak256("ERC3156FlashBorrower.onFlashLoan")` (at least, if the operation is a success)
        require(receiver.onFlashLoan(msg.sender, underlyingToken, amount, flashLoanFee, data) == keccak256("ERC3156FlashBorrower.onFlashLoan"),
            "TokenPool.flashLoan: receiver.onFlashLoan failure");

        // if any underlyingTokens have been provided to the contract, then convert them to more aTokens
        uint256 underlyingTokenBalance = IERC20(underlyingToken).balanceOf(address(this));
        if (underlyingTokenBalance != 0) {
            lendingPool.supply(underlyingToken, underlyingTokenBalance, address(this), REFERRAL_CODE);
        }

        // check that the loan has been properly paid
        uint256 aTokenBalanceAfter = _aTokenBalance();
        require(aTokenBalanceAfter >= aTokenBalanceBefore + flashLoanFee, "TokenPool.flashLoan: insufficient fee payment");

        // emit event
        emit FlashLoanExecuted(amount, flashLoanFee);

        // this is part of ERC3156
        return true;
    }

    /**
     * @dev The amount of currency available to be lended.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     * @dev ERC-3156 requires that this function returns '0' if this contract doesn't support the token
     */
    function maxFlashLoan(address token) external view returns (uint256) {
        if (token != underlyingToken && token != address(aToken)) {
            return 0;
        }
        return _aTokenBalance();
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     * @dev ERC-3156 requires that this function **reverts** if this contract doesn't support the token
     */
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        // this is part of ERC3156
        if (token != underlyingToken && token != address(aToken)) {
            revert("TokenPool.flashFee: token != underlyingToken");
        }
        // simple fee calculated using Basis Points ('BIPS')
        return (amount * flashLoanFeeBips) / MAX_BIPS;
    }

    /// @notice Internal getter function for this contract's aToken balance
    function _aTokenBalance() internal view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}
