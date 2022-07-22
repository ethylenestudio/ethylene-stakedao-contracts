const { ethers, network } = require("hardhat");

const CRV_HOLDER = "0x32D03DB62e464c9168e41028FFa6E9a05D8C6451";
const CRV_ADDRESS = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const RECEIVER_ADDRESS = "0x55aEd0ce035883626e536254dda2F23a5b5D977f";

const TOKEN_ABI = [
    "function transfer(address _to, uint256 _value) returns(uint256)",
    "function balanceOf(address arg1) returns(uint256)"
];


(async function main() {
    let crv_holder, crv;
    
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [CRV_HOLDER],
    });
    
    crv_holder = await ethers.getSigner(CRV_HOLDER);
    crv = new ethers.Contract(CRV_ADDRESS, TOKEN_ABI, ethers.provider);
   
    await crv.connect(crv_holder).transfer(RECEIVER_ADDRESS, ethers.utils.parseEther("100"));
    
})().then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

