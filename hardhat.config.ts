import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-web3";
import "@tenderly/hardhat-tenderly";
// import "hardhat-gas-reporter";
import '@typechain/hardhat';
import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/types";
import "solidity-coverage";
import "hardhat-contract-sizer";

dotenv.config();

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    // gasReporter: {
    //   currency: 'USD',
    //   gasPrice: 100
    // },
    paths: {
        sources: './contracts',
        tests: './test',
        artifacts: "./build/artifacts",
        cache: "./build/cache"
    },
    networks: {
        hardhat: {
            forking: {
                url: `https://api.avax.network/ext/bc/C/rpc`,
                blockNumber: 8311876
            },
            accounts: [
                // 5 accounts with 10^14 ETH each
                // Addresses:
                //   your address generated from the private key
                //   0x6824c889f6EbBA8Dac4Dd4289746FCFaC772Ea56
                //   0xCFf94465bd20C91C86b0c41e385052e61ed49f37
                //   0xEBAf3e0b7dBB0Eb41d66875Dd64d9F0F314651B3
                //   0xbFe6D5155040803CeB12a73F8f3763C26dd64a92

                {
                    privateKey: `${process.env.PRIVATE_KEYS}`,
                    balance: '1000000000000000000000000000000000000',
                },
                {
                    privateKey: '0xca3547a47684862274b476b689f951fad53219fbde79f66c9394e30f1f0b4904',
                    balance: '1000000000000000000000000000000000000',
                },
                {
                    privateKey: '0x4bad9ef34aa208258e3d5723700f38a7e10a6bca6af78398da61e534be792ea8',
                    balance: '1000000000000000000000000000000000000',
                },
                {
                    privateKey: '0xffc03a3bd5f36131164ad24616d6cde59a0cfef48235dd8b06529fc0e7d91f7c',
                    balance: '1000000000000000000000000000000000000',
                },
                {
                    privateKey: '0x380c430a9b8fa9cce5524626d25a942fab0f26801d30bfd41d752be9ba74bd98',
                    balance: '1000000000000000000000000000000000000',
                },
            ],
            allowUnlimitedContractSize: false,
            blockGasLimit: 800000000000000,
            gas: 80000000,
            loggingEnabled: false,
        },
        development: {
            url: 'http://127.0.0.1:8545',
            accounts: [`${process.env.PRIVATE_KEYS}`],
            gas: 12400000,
            timeout: 1000000,
            gasPrice: 100e9
        },
        avax: {
            url: `https://api.avax.network/ext/bc/C/rpc`,
            accounts: [`${process.env.PRIVATE_KEYS}`],
            gasPrice: 40 * 1000000000,
            timeout: 200000,
        }
    },
    solidity: {
        compilers: [
            {
                version: '0.8.9',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.7.6',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.6.12',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    mocha: {
        timeout: 500000,
    },
    // tenderly: {
    //   username: "Yongkhang",
    //   project: "pendle-finance"
    // },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: process.env.ETHERSCAN_KEY
    },

    contractSizer: {
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
        only: [],
    }
};

export default config;
