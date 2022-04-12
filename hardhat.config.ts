import '@typechain/hardhat';
import { HardhatUserConfig } from "hardhat/types";
import "hardhat-contract-sizer";

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
                version: '0.8.9',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 0,
                    },
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
