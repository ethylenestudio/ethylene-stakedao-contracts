const { ethers, network } = require("hardhat");
let provider = ethers.provider;

const CRV_HOLDER = "0x32D03DB62e464c9168e41028FFa6E9a05D8C6451";
const sdCRV_HOLDER = "0x230CefA37119109cC20351Ef6a0a92291a07DA32";
const CRV_ADDRESS = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const sdCRV_ADDRESS = "0xD1b5651E55D4CeeD36251c61c50C889B36F6abB5";
const RECEIVER_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

const TOKEN_ABI = [
  "function transfer(address _to, uint256 _value) returns(uint256)",
  "function balanceOf(address arg1) view returns(uint256)",
];

(async function main() {
  let sdcrv_holder, crv_holder, crv, sdcrv;

  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [CRV_HOLDER],
  });
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [sdCRV_HOLDER],
  });

  crv_holder = await ethers.getSigner(CRV_HOLDER);
  sdcrv_holder = await ethers.getSigner(sdCRV_HOLDER);
  crv = new ethers.Contract(CRV_ADDRESS, TOKEN_ABI, provider);

  sdcrv_holder = await ethers.getSigner(sdCRV_HOLDER);
  sdcrv = new ethers.Contract(sdCRV_ADDRESS, TOKEN_ABI, provider);

  await crv
    .connect(crv_holder)
    .transfer(RECEIVER_ADDRESS, ethers.utils.parseEther("500"));
  await sdcrv
    .connect(sdcrv_holder)
    .transfer(RECEIVER_ADDRESS, ethers.utils.parseEther("100"));

  let crv_balance = await crv.balanceOf(RECEIVER_ADDRESS);
  let sdcrv_balance = await sdcrv.balanceOf(RECEIVER_ADDRESS);
  console.log("CRV:", crv_balance, "\nsdCRV:", sdcrv_balance);
})()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
