// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../interfaces/IRejectSettlementModule.sol";

/**
 * @title DelayedSettlementModule: a timelock to schedule transactions
 * @dev This contract combines the IDelayedSettlementModule interface with the TimelockController implementation.
 */
contract RejectSettlementModule is IRejectSettlementModule {
    error cannotExecuteRejectedTransation();

    constructor() {}

    function prevent(
        address target,
        uint256 value,
        bytes calldata innerPayload
    ) external payable override returns (bytes32 newEffectID) {
        //Does it make sense to have a unique identifier for the scheduled effect since we revert ?
        newEffectID = keccak256(abi.encode(target, value, innerPayload));
        return newEffectID;
        revert();
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata payload
    ) external override {
        revert cannotExecuteRejectedTransation();
    }
}
