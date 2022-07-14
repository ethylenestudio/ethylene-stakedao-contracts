require("@nomicfoundation/hardhat-toolbox");
const ALCHEMY_KEY =
  "https://eth-mainnet.g.alchemy.com/v2/5_2gUfKiXtK6TsbqX6kNO6AjiEyMVsJX";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  hardhat: {
    forking: {
      url: ALCHEMY_KEY,
    },
  },
};
