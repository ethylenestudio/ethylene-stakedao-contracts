const { expect } = require("chai");
const { ethers } = require("hardhat");
const provider = ethers.provider;

// Strategy Constructor Address
const ANGLE_VAULT_ADDRESS = "0x1BD865ba36A510514d389B2eA763bad5d96b6ff9";
const ANGLE_STRATEGY_ADDRESS = "0x22635427C72e8b0028FeAE1B5e1957508d9D7CAF";
const ONEINCH_ROUTER_ADDRESS = "0x1111111254fb6c44bAC0beD2854e76F90643097d";
const ANGLE_SM_ADDRESS = "0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87";
const ANGLE_GAUGE_ADDRESS = "0xb40432243E4F317cE287398e72Ab8f0312fc2FE8";
const SANFRAX_EUR_ADDRESS = "0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE";

// Addresses to be Imprersonated
const SANFRAX_EUR_HOLDER = "0xA2dEe32662F6243dA539bf6A8613F9A9e39843D3"; // Has 100 token

describe("Fixed Strategy Contract", function () {
    let owner, alice, bob;

    let oneInchContract, oneInch;
    let strContract, strategy;

    before(async function () {
        [owner, alice, bob] = await ethers.getSigners();

        oneInchContract = await ethers.getContractFactory("MockOneInch");
        oneInch = await oneInchContract.deploy();

        strContract = await ethers.getContractFactory("FixedStrategy");
        strategy = await strContract.deploy(ANGLE_VAULT_ADDRESS, ANGLE_STRATEGY_ADDRESS, ONEINCH_ROUTER_ADDRESS, ANGLE_SM_ADDRESS, ANGLE_GAUGE_ADDRESS, SANFRAX_EUR_ADDRESS);
    });

    it("Deploys", async function() {
        expect(oneInch.address).to.be.properAddress;
        expect(strategy.address).to.be.properAddress;
    });
});