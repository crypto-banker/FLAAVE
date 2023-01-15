// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.2;

import "lib/aave-v3-core/contracts/interfaces/IPool.sol";

interface IAToken_UndocumentedFunctions {
    function POOL() external view returns (IPool);
}
