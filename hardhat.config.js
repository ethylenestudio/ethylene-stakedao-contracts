require("@nomiclabs/hardhat-waffle");

const ALCHEMY_KEY =
  "https://eth-mainnet.g.alchemy.com/v2/JZWiNWabjpScd5RigSOZZwGANErZecOW";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: ALCHEMY_KEY,
        blockNumber: 15140908,
      },
    },
  },
};
