import './helpers/hardhat-imports';
import path from 'path';

import chalk from 'chalk';
import glob from 'glob';
import { removeConsoleLog } from 'hardhat-preprocessor';
import type { HardhatUserConfig } from 'hardhat/config';

import { getMnemonic } from './helpers/functions';

import { hardhatNamedAccounts } from '~common/constants';
import { getNetworks } from '~common/functions';
import scaffoldConfig from '~common/scaffold.config';
import { hardhatArtifactsDir, hardhatDeploymentsDir, typechainOutDir } from '~helpers/constants/toolkitPaths';

// eslint-disable-next-line no-duplicate-imports
/**
 * ⛳️⛳️⛳️⛳️⛳️⛳️⛳️⛳️⛳️⛳️
 * NOTES:
 * - All the task are located in the tasks folder
 * - network definitions are in getNetworks in the '@scaffold-eth/common/src workspace: `'@scaffold-eth/common/src/functions`
 * - Named hardhat accounts are in the '@scaffold-eth/common/src workspace: `'@scaffold-eth/common/src/constants`
 * - Files generated by hardhat will be outputted to the ./generated folder
 */

/**
 * this loads all the tasks from the tasks folder
 */
if (process.env.BUILDING !== 'true') {
  try {
    glob.sync('./tasks/**/*.ts').forEach((file: string) => {
      require(path.resolve(file));
    });
  } catch (e) {
    console.log(chalk.yellow('--------------------------'));
    console.warn(chalk.red('🙋 Make sure to compile hardhat first: `yarn compile`'));
    console.log(chalk.yellow('...or run hardhat with process.env.BUILDING = true'));
    console.log(chalk.yellow('If you do not compile hardhat, you cannot be able to load the tasks in the tasks folder'));
    console.log(chalk.yellow('--------------------------'));
    console.log(e);
  }
}

/**
 * loads network list and config from '@scaffold-eth/common/src
 */
const networks = {
  ...getNetworks({
    accounts: {
      mnemonic: getMnemonic(),
    },
  }),
  localhost: {
    url: 'http://localhost:8545',
    /*
      if there is no mnemonic, it will just use account 0 of the hardhat node to deploy
      (you can put in a mnemonic here to set the deployer locally)
    */
    // accounts: {
    //   mnemonic: getMnemonic(),
    // },
  },
  'mantle-testnet': {
    url: 'https://rpc.testnet.mantle.xyz/',
    accounts: {
      mnemonic: getMnemonic(),
    },
  },
  scrollAlpha: {
    url: 'https://alpha-rpc.scroll.io/l2',
    accounts: {
      mnemonic: getMnemonic(),
    },
  },
};

/**
 * See {@link hardhatNamedAccounts} to define named accounts
 */
const namedAccounts = hardhatNamedAccounts as {
  [name: string]: string | number | { [network: string]: null | number | string };
};

export const config: HardhatUserConfig = {
  preprocess: {
    eachLine: removeConsoleLog((hre) => hre.network.name !== 'hardhat' && hre.network.name !== 'localhost'),
  },
  defaultNetwork: scaffoldConfig.runtime.targetNetwork,
  namedAccounts: namedAccounts,
  networks: networks,
  solidity: {
    compilers: [
      {
        version: '0.8.18',
        settings: {
          optimizer: {
            enabled: true,
            runs: 250,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },
    ],
  },
  mocha: {
    bail: false,
    allowUncaught: false,
    require: ['ts-node/register'],
    timeout: 30000,
    slow: 9900,
    reporter: process.env.GITHUB_ACTIONS === 'true' ? 'mocha-junit-reporter' : 'spec',
    reporterOptions: {
      mochaFile: 'testresult.xml',
      toConsole: true,
    },
  },
  watcher: {
    'auto-compile': {
      tasks: ['compile'],
      files: ['./contracts'],
      verbose: false,
    },
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: 'USD',
  },
  dodoc: {
    runOnCompile: false,
    debugMode: false,
    keepFileStructure: true,
    freshOutput: true,
    outputDir: './generated/docs',
    include: ['contracts'],
  },
  paths: {
    cache: './generated/hardhat/cache',
    artifacts: hardhatArtifactsDir,
    deployments: hardhatDeploymentsDir,
    deploy: './deploy/hardhat-deploy',
    tests: './tests/hardhat-tests',
  },
  typechain: {
    outDir: typechainOutDir,
    discriminateTypes: true,
  },
  etherscan: {
    apiKey: {
      'mantle-testnet': 'xyz',
      scrollAlpha: 'abc',
    },
    customChains: [
      {
        network: 'mantle-testnet',
        chainId: 5001,
        urls: {
          apiURL: 'https://explorer.testnet.mantle.xyz/api',
          browserURL: 'https://explorer.testnet.mantle.xyz',
        },
      },
      {
        network: 'scrollAlpha',
        chainId: 534353,
        urls: {
          apiURL: 'https://blockscout.scroll.io/api',
          browserURL: 'https://blockscout.scroll.io/',
        },
      },
    ],
  },
};
export default config;
