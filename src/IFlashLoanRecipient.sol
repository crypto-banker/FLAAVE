// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

interface IFlashLoanRecipient {
    function executeOperation(
        address underlyingAsset,
        uint256 loanSize,
        uint256 flashLoanFee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
