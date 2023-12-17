// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./LimitRouterBase.sol";
import "../core/libraries/Errors.sol";

contract PendleLimitRouter is LimitRouterBase {
    using Address for address;

    constructor(address _WNATIVE) LimitRouterBase(_WNATIVE) {
        _disableInitializers();
    }

    /// @notice Cancels multiple orders by setting remaining amount to zero
    function cancelBatch(Order[] calldata orders) external {
        for (uint256 i = 0; i < orders.length; ++i) {
            cancelSingle(orders[i]);
        }
    }

    /// @notice Cancels order by setting remaining amount to zero
    function cancelSingle(Order calldata order) public {
        require(order.maker == msg.sender, "LOP: Access denied");

        bytes32 orderHash = hashOrder(order);
        require(_status[orderHash].remaining != _ORDER_FILLED, "LOP: already filled");
        _status[orderHash].remaining = _ORDER_FILLED;

        emit OrderCanceled(msg.sender, orderHash);
    }

    function orderStatusesRaw(
        bytes32[] memory orderHashes
    ) public view returns (uint256[] memory remainingsRaw, uint256[] memory filledAmounts) {
        uint256 len = orderHashes.length;
        remainingsRaw = new uint256[](len);
        filledAmounts = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            OrderStatus memory status = _status[orderHashes[i]];
            (remainingsRaw[i], filledAmounts[i]) = (status.remaining, status.filledAmount);
        }
    }

    function orderStatuses(
        bytes32[] memory orderHashes
    ) external view returns (uint256[] memory remainings, uint256[] memory filledAmounts) {
        (remainings, filledAmounts) = orderStatusesRaw(orderHashes);
        for (uint256 i = 0; i < remainings.length; i++) {
            require(remainings[i] != _ORDER_DOES_NOT_EXIST, "LOP: Unknown order");
            unchecked {
                remainings[i] -= 1;
            }
        }
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function simulate(address target, bytes calldata data) external payable {
        (bool success, bytes memory result) = target.delegatecall(data);
        revert Errors.SimulationResults(success, result);
    }
}
