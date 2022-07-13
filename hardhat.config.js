require("@nomicfoundation/hardhat-toolbox");
const ALCHEMY_KEY = "https://eth-mainnet.g.alchemy.com/v2/uBFEwiW1y71dOMxFcX7CWoQnV1_oUoRu"

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  hardhat: {
    forking: {
      url: ALCHEMY_KEY,
    },
  }
};