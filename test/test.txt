const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FixedStrategyDW", function () {
  it("Should deposit & withdraw properly", async function () {
    //deploying and assigning signers
    const [deployer, randomAcc, Acc2, Acc3] = await ethers.getSigners();
    const FixedStrategy = await ethers.getContractFactory("FixedStrategy");
    const fixedStrategy = await FixedStrategy.deploy(
      "0x1BD865ba36A510514d389B2eA763bad5d96b6ff9",
      "0x22635427c72e8b0028feae1b5e1957508d9d7caf",
      "0x1111111254fb6c44bac0bed2854e76f90643097d",
      "0xb6261be83ea2d58d8dd4a73f3f1a353fa1044ef7",
      "0xb3b209bb213a5da5b947c56f2c770b3e1015f1fe"
    );
  });
});

//stakeDAO claims angle => AngleStrategy.claim(address -> sanFRAX/EUR LP address) -> sends to liquidityGauge
