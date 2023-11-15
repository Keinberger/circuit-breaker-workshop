// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IERC7265CircuitBreaker} from "../interfaces/IERC7265CircuitBreaker.sol";
import {IAssetCircuitBreaker} from "../interfaces/IAssetCircuitBreaker.sol";
import {ISettlementModule} from "../interfaces/ISettlementModule.sol";

import {CircuitBreaker} from "./CircuitBreaker.sol";

import {Limiter} from "../static/Structs.sol";
import {LimiterLib, LimitStatus} from "../utils/LimiterLib.sol";

contract AssetCircuitBreaker is CircuitBreaker, IAssetCircuitBreaker {
    using LimiterLib for Limiter;
    using SafeERC20 for IERC20;

    error TokenCirtcuitBreaker__NativeTransferFailed();

    uint8 private constant FUNCTION_SELECTOR_SIZE = 4;
    bytes4 private constant TRANSFER_SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));

    // Using address(1) as a proxy for native token (ETH, BNB, etc), address(0) could be problematic
    address public immutable NATIVE_ADDRESS_PROXY = address(1);

    constructor(
        uint256 _rateLimitCooldownPeriod,
        uint256 _withdrawalPeriod,
        uint256 _liquidityTickLength,
        address _initialOwner
    ) CircuitBreaker(_rateLimitCooldownPeriod, _withdrawalPeriod, _liquidityTickLength, _initialOwner) {}

    /// @dev OWNABLE FUNCTIONS

    function registerAsset(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold,
        address _settlementModule
    ) external override onlyOwner {
        _addSecurityParameter(
            getTokenIdentifier(_asset),
            _minLiqRetainedBps,
            _limitBeginThreshold,
            _settlementModule
        );
    }

    function updateAssetParams(
        address _asset,
        uint256 _minLiqRetainedBps,
        uint256 _limitBeginThreshold,
        address _settlementModule
    ) external override onlyOwner {
        _updateSecurityParameter(
            getTokenIdentifier(_asset),
            _minLiqRetainedBps,
            _limitBeginThreshold,
            _settlementModule
        );
    }

    /// @dev TOKEN FUNCTIONS

    function onTokenInflow(
        address _token,
        uint256 _amount
    ) external override onlyProtected onlyOperational {
        _increaseParameter(
            getTokenIdentifier(_token),
            _amount,
            _token,
            0,
            new bytes(0)
        );
        emit AssetDeposit(_token, msg.sender, _amount);
    }

    // @dev Funds have been transferred to the circuit breaker before calling onTokenOutflow
    function onTokenOutflow(
        address _token,
        uint256 _amount,
        address _recipient
    ) external override onlyProtected onlyOperational {
        // compute calldata to call the erc20 contract and transfer funds to _recipient
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("transfer(address,uint256)")),
            _recipient,
            _amount
        );

        bool firewallTriggered = _decreaseParameter(
            getTokenIdentifier(_token),
            _amount,
            _token,
            0,
            data
        );
        if (!firewallTriggered)
            _safeTransferIncludingNative(_token, _recipient, _amount);

        emit AssetDeposit(_token, msg.sender, _amount);
    }

    function onNativeAssetInflow(
        uint256 _amount
    ) external override onlyProtected onlyOperational {
        _increaseParameter(
            getTokenIdentifier(NATIVE_ADDRESS_PROXY),
            _amount,
            address(0),
            0,
            new bytes(0)
        );
        emit AssetDeposit(NATIVE_ADDRESS_PROXY, msg.sender, _amount);
    }

    function onNativeAssetOutflow(
        address _recipient
    ) external payable override onlyProtected onlyOperational {
        bool firewallTriggered = _decreaseParameter(
            getTokenIdentifier(NATIVE_ADDRESS_PROXY),
            msg.value,
            _recipient,
            msg.value,
            new bytes(0)
        );

        if (!firewallTriggered)
            _safeTransferIncludingNative(
                NATIVE_ADDRESS_PROXY,
                _recipient,
                msg.value
            );

        emit AssetDeposit(NATIVE_ADDRESS_PROXY, msg.sender, msg.value);
    }

    function isTokenRateLimited(address token) external view returns (bool) {
        return
            limiters[getTokenIdentifier(token)].status() ==
            LimitStatus.Triggered;
    }

    /// @dev INTERNAL FUNCTIONS

    function getTokenIdentifier(address token) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(token));
    }

    /// @dev FIREWALL TRIGGER OVERRIDE

    function _onCircuitBreakerTrigger(
        Limiter storage limiter,
        address settlementTarget,
        uint256 settlementValue,
        bytes memory settlementPayload
    ) internal override {
        // check if bytes are just 0
        // if not => extract recipient and value from abi encoded bytes data
        // use the data to call _safeTransferIncludingNative

        if (settlementPayload.length > 0) {
            // decoding the calldata
            // extracting the function selector (which is always bytes4) from the bytes calldata, in order to properly decode the calldata
            bytes memory dataWithoutSelector = new bytes(
                settlementPayload.length - FUNCTION_SELECTOR_SIZE
            );
            for (uint256 i = 0; i < dataWithoutSelector.length; i++) {
                dataWithoutSelector[i] = settlementPayload[
                    i + FUNCTION_SELECTOR_SIZE
                ];
            }
            (, uint256 amount) = abi.decode(
                dataWithoutSelector,
                (address, uint256)
            );

            _safeTransferIncludingNative(
                settlementTarget,
                address(limiter.settlementModule),
                amount
            );
        } else {
            _safeTransferIncludingNative(
                NATIVE_ADDRESS_PROXY,
                address(limiter.settlementModule),
                settlementValue
            );
        }

        limiter.settlementModule.prevent(
            settlementTarget,
            settlementValue,
            settlementPayload
        );
    }

    function _safeTransferIncludingNative(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        if (_token == NATIVE_ADDRESS_PROXY) {
            (bool success, ) = _recipient.call{value: _amount}("");
            if (!success) revert TokenCirtcuitBreaker__NativeTransferFailed();
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }
}
