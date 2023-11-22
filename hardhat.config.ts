import '@typechain/hardhat';
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/types";

const config: HardhatUserConfig = {
    paths: {
        sources: './contracts',
        tests: './test',
        artifacts: "./build/artifacts",
        cache: "./build/cache"
    },
    solidity: {
        compilers: [
            {
                version: '0.8.23',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 0,
                    },
                    evmVersion: 'paris'
                },
            }
        ],
    },
    contractSizer: {
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
        only: [],
    }
};

export default config;
