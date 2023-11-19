// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrvPool {
    function coins(uint256 i) external view returns (address);

    function get_virtual_price() external view returns (uint256);

    function lp_token() external view returns (address);

    function fee() external view returns (uint256);

    function admin_fee() external view returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx // The amount of i being exchanged.
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy // The amount of i being exchanged.
    ) external returns (uint256);

    function add_liquidity(uint256[2] memory _deposit_amount, uint256 _min_amount) external returns (uint256 lpOut);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount
    ) external returns (uint256 tokenOut);

    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit) external view returns (uint256);

    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i) external view returns (uint256);

    function balances(uint256 i) external view returns (uint256);

    function A_precise() external view returns (uint256);
}
