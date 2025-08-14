import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import { HardhatUserConfig } from 'hardhat/types';

function viaIR(version: string, runs: number) {
    return {
        version,
        settings: {
            optimizer: {
                enabled: true,
                runs: runs,
            },
            evmVersion: 'shanghai',
            viaIR: true,
        },
    };
}

const config: HardhatUserConfig = {
    paths: {
        sources: './contracts',
        tests: './test',
        artifacts: './build/artifacts',
        cache: './build/cache',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.30',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 0,
                    },
                    evmVersion: 'shanghai',
                },
            },
        ],
        overrides: {
            'contracts/router/ActionAddRemoveLiqV3.sol': viaIR('0.8.30', 9500),
            'contracts/router/ActionMiscV3.sol': viaIR('0.8.23', 1000000),
            'contracts/router/ActionSimple.sol': viaIR('0.8.23', 1000000),
            'contracts/router/ActionSwapPTV3.sol': viaIR('0.8.23', 1000000),
            'contracts/router/ActionSwapYTV3.sol': viaIR('0.8.23', 1000000),
            'contracts/router/ActionCallbackV3.sol': viaIR('0.8.23', 1000000),
            'contracts/router/PendleRouterV3.sol': viaIR('0.8.23', 1000000),
            'contracts/limit/PendleLimitRouter.sol': viaIR('0.8.23', 1000000),
            'contracts/oracles/factory/PendleChainlinkOracleFactory.sol': viaIR(
                '0.8.23',
                35000,
            ),
        },
    },
    contractSizer: {
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
        only: [],
    },
};

export default config;
