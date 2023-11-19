pragma solidity >=0.8.0;

interface ICamelotNFTFactory {
    function getPool(address lp) external view returns (address nftPool);

    function grailToken() external view returns (address);

    function xGrailToken() external view returns (address);
}
