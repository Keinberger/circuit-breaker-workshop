// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./ISettlementModule.sol";

/**
 * @title Interface for the Delayed Settlement Module (DSM): a timelock to schedule transactions
 * @dev This interface defines the functions for :
 * - preventing settlement via scheduling
 * - executing settlement
 * - get paused status
 */
interface IDelayedSettlementModule is ISettlementModule {
    /**
     * @notice Returns the UNIX timestamp at which the last module pause occurred.
     * @dev The function may return 0 if the contract has not been paused yet.
     * It should return a value that's at least 2**248 if the contract is currently paused until further notice.
     * It should return 2**256 - 1.
     * @return pauseTimestamp The UNIX timestamp of the last pause.
     *
     * TODO: provide docs for the pausing mechanism
     */
    function pausedTill() external view returns (uint256 pauseTimestamp);
}
