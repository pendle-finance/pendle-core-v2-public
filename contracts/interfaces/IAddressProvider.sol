pragma solidity 0.8.17;

interface IAddressProvider {
    function get(uint256) external view returns (address);

    function set(uint256 id, address addr) external;
}
