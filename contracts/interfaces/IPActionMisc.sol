// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionMisc {
    struct MultiApproval {
        address[] tokens;
        address spender;
    }

    struct Call3 {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function approveInf(MultiApproval[] calldata) external;

    function batchExec(Call3[] calldata calls) external returns (Result[] memory returnData);
}
