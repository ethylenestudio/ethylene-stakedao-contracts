require("@nomicfoundation/hardhat-toolbox");
const private_key = require("./keys/privatekey.json");
const PRIVATE_KEY = private_key.key;
const ALCHEMY_KEY = "https://eth-mainnet.g.alchemy.com/v2/uBFEwiW1y71dOMxFcX7CWoQnV1_oUoRu"

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  hardhat: {
    forking: {
      url: ALCHEMY_KEY,
    },
    mainnet: {
      url: ALCHEMY_KEY,
      accounts: [`${PRIVATE_KEY}`]
    }
  }
};