const { expect } = require("chai");
const { ethers } = require("hardhat");
const provider = ethers.provider;

// Strategy Constructor Address
const ANGLE_VAULT_ADDRESS = "0x1BD865ba36A510514d389B2eA763bad5d96b6ff9";
const ANGLE_STRATEGY_ADDRESS = "0x22635427C72e8b0028FeAE1B5e1957508d9D7CAF";
const ONEINCH_ROUTER_ADDRESS = "0x1111111254fb6c44bAC0beD2854e76F90643097d";
const ANGLE_SM_ADDRESS = "0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87";
const ANGLE_GAUGE_ADDRESS = "0xB6261Be83EA2D58d8dd4a73f3F1A353fa1044Ef7";
const SANFRAX_EUR_ADDRESS = "0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE";

// Addresses to be Imprersonated
const SANFRAX_EUR_HOLDER = "0xA2dEe32662F6243dA539bf6A8613F9A9e39843D3"; // Has 100 token

// Helper ABIs
const TOKEN_ABI = [
    "function transfer(address to, uint256 amount) returns(bool)",
    "function approve(address spender, uint256 amount) returns(bool)",
    "function balanceOf(address owner) view returns(uint256)",
];

// Helper fns

// Increases block timestamp -> "value" days
async function increaseDays(value) {
    value = value * 3600 * 24;
    if (!ethers.BigNumber.isBigNumber(value)) {
        value = ethers.BigNumber.from(value);
    }
    await provider.send('evm_increaseTime', [value.toNumber()]);
    await provider.send('evm_mine');
}

// Gives current block timestamp
async function getBlockTiemstamp() {
    let block_number, block, block_timestamp;

    block_number = await provider.getBlockNumber();;
    block = await provider.getBlock(block_number);
    block_timestamp = block.timestamp;

    return block_timestamp;
}

// Converts any BN ether values to regular counts
function ethToNum(val) {
    return Number(ethers.utils.formatEther(val))
}

describe("Fixed Strategy Contract", function () {
    let owner, alice, bob, sanfrax_eur_holder;

    let oneInchContract, oneInch;
    let strContract, strategy;
    let sanfrax_eur;

    before(async function () {
        [owner, alice, bob] = await ethers.getSigners();

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [SANFRAX_EUR_HOLDER],
        });
        sanfrax_eur_holder = await ethers.getSigner(SANFRAX_EUR_HOLDER);

        oneInchContract = await ethers.getContractFactory("MockOneInch");
        oneInch = await oneInchContract.deploy();

        strContract = await ethers.getContractFactory("FixedStrategy");
        strategy = await strContract.deploy(ANGLE_VAULT_ADDRESS, ANGLE_STRATEGY_ADDRESS, ONEINCH_ROUTER_ADDRESS, ANGLE_SM_ADDRESS, ANGLE_GAUGE_ADDRESS, SANFRAX_EUR_ADDRESS);

        sanfrax_eur = new ethers.Contract(SANFRAX_EUR_ADDRESS, TOKEN_ABI, provider);;
    });

    it("Deploys", async function() {
        expect(oneInch.address).to.be.properAddress;
        expect(strategy.address).to.be.properAddress;
        expect(sanfrax_eur.address).to.be.properAddress;
    });
});