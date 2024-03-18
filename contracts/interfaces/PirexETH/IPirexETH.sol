pragma solidity ^0.8.0;

interface IPirexETH {
    enum Fees {
        Deposit,
        Redemption,
        InstantRedemption
    }

    function deposit(
        address receiver,
        bool shouldCompound
    ) external payable returns (uint256 postFeeAmount, uint256 feeAmount);

    function instantRedeemWithPxEth(
        uint256 _assets,
        address _receiver
    ) external returns (uint256 postFeeAmount, uint256 feeAmount);

    function fees(Fees _feeType) external view returns (uint256);

    function pxEth() external view returns (address);

    function autoPxEth() external view returns (address);

    function buffer() external view returns (uint256);
}
