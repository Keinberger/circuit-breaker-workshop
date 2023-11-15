// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ISettlementModule.sol";

/**
 * @title Interface for the Reject Settlement Module: reject transactions when the firewall triggers
 * @dev This interface defines the functions for :
 * - preventing settlement via rejecting
 * - executing settlement
 */
interface IRejectSettlementModule is ISettlementModule {

}
