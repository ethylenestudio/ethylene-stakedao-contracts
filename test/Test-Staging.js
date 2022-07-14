const { expect } = require("chai");
const { ethers, network } = require("hardhat");
let provider = new ethers.getDefaultProvider("http://localhost:8545/");
const abi = require("./tokenAbi.json");

// Strategy Constructor Address
const ANGLE_VAULT_ADDRESS = "0x1BD865ba36A510514d389B2eA763bad5d96b6ff9";
const ANGLE_STRATEGY_ADDRESS = "0x22635427C72e8b0028FeAE1B5e1957508d9D7CAF";
const ONEINCH_ROUTER_ADDRESS = "0x1111111254fb6c44bAC0beD2854e76F90643097d";
const ANGLE_SM_ADDRESS = "0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87";
const ANGLE_GAUGE_ADDRESS = "0xB6261Be83EA2D58d8dd4a73f3F1A353fa1044Ef7";
const SANFRAX_EUR_ADDRESS = "0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE";

// Addresses to be Imprersonated
const SANFRAX_EUR_HOLDER = "0xA2dEe32662F6243dA539bf6A8613F9A9e39843D3"; // Has 100 token

// Helper fns

// Increases block timestamp -> "value" days
async function increaseDays(value) {
  value = value * 3600 * 24;
  if (!ethers.BigNumber.isBigNumber(value)) {
    value = ethers.BigNumber.from(value);
  }
  await network.provider.send("evm_increaseTime", [value.toNumber()]);
  await network.provider.send("evm_mine");
}

// Gives current block timestamp
async function getBlockTiemstamp() {
  let block_number, block, block_timestamp;

  block_number = await provider.getBlockNumber();
  block = await provider.getBlock(block_number);
  block_timestamp = block.timestamp;

  return block_timestamp;
}

// Converts any BN ether values to regular counts
function ethToNum(val) {
  return Number(ethers.utils.formatEther(val));
}

describe("Fixed Strategy Contract", function () {
  let owner, alice, bob, sanfrax_eur_holder;
  let oneInchContract, oneInch;
  let strategy;
  let sanfrax_eur;

  before(async function () {
    [owner, alice, bob] = await ethers.getSigners();

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [SANFRAX_EUR_HOLDER],
    });
    sanfrax_eur_holder = await ethers.getSigner(SANFRAX_EUR_HOLDER);

    oneInchContract = await ethers.getContractFactory("MockOneInch");
    oneInch = await oneInchContract.deploy();

    const strContract = await ethers.getContractFactory("FixedStrategy");
    strategy = await strContract.deploy(
      ANGLE_VAULT_ADDRESS,
      ANGLE_STRATEGY_ADDRESS,
      ONEINCH_ROUTER_ADDRESS,
      ANGLE_SM_ADDRESS,
      ANGLE_GAUGE_ADDRESS,
      SANFRAX_EUR_ADDRESS
    );
    await strategy.deployed();

    sanfrax_eur = new ethers.Contract(
      SANFRAX_EUR_ADDRESS,
      abi,
      sanfrax_eur_holder
    );
  });

  //////////////////////////////////////////

  it("Deploys", async function () {
    expect(oneInch.address).to.be.properAddress;
    expect(strategy.address).to.be.properAddress;
    expect(sanfrax_eur.address).to.be.properAddress;
  });

  //////////////////////////////////////////

  it("Sends ether to Impersonate Account & Sends sanfrax to Owner, Alice, Bob", async function () {
    const tx = {
      to: sanfrax_eur_holder.address,
      value: ethers.utils.parseEther("5"),
    };
    await owner.sendTransaction(tx);

    const balanceImp = await sanfrax_eur.balanceOf(sanfrax_eur_holder.address);
    expect(balanceImp).to.equal(ethers.utils.parseEther("100"));

    const transferImp = await sanfrax_eur.transfer(
      owner.address,
      ethers.utils.parseEther("50")
    );
    await transferImp.wait();

    const transferImp2 = await sanfrax_eur.transfer(
      alice.address,
      ethers.utils.parseEther("25")
    );
    await transferImp2.wait();

    const transferImp3 = await sanfrax_eur.transfer(
      bob.address,
      ethers.utils.parseEther("25")
    );
    await transferImp3.wait();

    const balanceOwn = await sanfrax_eur.balanceOf(owner.address);
    expect(balanceOwn).to.equal(ethers.utils.parseEther("50"));

    const balanceAlice = await sanfrax_eur.balanceOf(alice.address);
    expect(balanceAlice).to.equal(ethers.utils.parseEther("25"));

    const balanceBob = await sanfrax_eur.balanceOf(bob.address);
    expect(balanceBob).to.equal(ethers.utils.parseEther("25"));
  });

  //////////////////////////////////////////

  it("Deposits sanToken to contract on behalf of owner", async function () {
    const approveToken = await sanfrax_eur
      .connect(owner)
      .approve(strategy.address, ethers.utils.parseEther("100"));
    await approveToken.wait();
    const depositFunc = await strategy.deposit(ethers.utils.parseEther("50"));
    await depositFunc.wait();

    const ownerShare = await strategy.userToShare(owner.address);
    expect(ownerShare).to.equal(ethers.utils.parseEther("50"));
  });

  //////////////////////////////////////////

  it("Deposits sanToken to contract on behalf of Alice", async function () {
    const approveToken = await sanfrax_eur
      .connect(alice)
      .approve(strategy.address, ethers.utils.parseEther("100"));
    await approveToken.wait();

    const pricePerShare = await strategy.pricePerShare();
    const depositFunc = await strategy
      .connect(alice)
      .deposit(ethers.utils.parseEther("25"));
    await depositFunc.wait();
    const aliceShare = await strategy.userToShare(alice.address);
    expect(parseInt(ethers.utils.formatEther(aliceShare))).to.equal(
      parseInt(ethers.utils.parseEther("25") / pricePerShare)
    );
  });
});
