// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ICrvPool {
    function get_virtual_price() external view returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx // The amount of i being exchanged.
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy, // The amount of i being exchanged.
        address _receiver
    ) external returns (uint256);

    function add_liquidity(
        uint256[] memory _deposit_amount,
        uint256 _min_amount,
        address _receiver
    ) external returns (uint256);

    function add_liquidity(
        uint256[2] memory _deposit_amount,
        uint256 _min_amount
    ) external;

    function add_liquidity(
        uint256[3] memory _deposit_amount,
        uint256 _min_amount
    ) external;

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[] memory _min_amounts,
        address _receiver
    ) external returns (uint256[] memory);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount
    ) external;

    function calc_token_amount(uint256[] memory _amounts, bool _is_deposit)
        external
        view
        returns (uint256);

    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit)
        external
        view
        returns (uint256);

    function calc_token_amount(uint256[3] memory _amounts, bool _is_deposit)
        external
        view
        returns (uint256);


    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i)
        external
        view
        returns (uint256);
}
