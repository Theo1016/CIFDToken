const { bytecode } = require("../artifacts/contracts/Vault.sol/Vault.json");
const { encoder, create2Address } = require("../utils/utils.js")

const main = async () => {
    const factoryAddr = "0x3379b6E9d4BD39B0f4C8c9C2277a6BcA6c13E728";
    const unlockTime = "1657852422"
    const saltHex = ethers.utils.id("CIFDAQ");
    const initCode = bytecode + encoder(["uint"], [unlockTime]);

    const create2Addr = create2Address(factoryAddr, saltHex, initCode);
    console.log("precomputed address:", create2Addr);
    
    const Factory = await ethers.getContractFactory("DeterministicDeployFactory");
    const factory = await Factory.attach(factoryAddr);

    const lockDeploy = await factory.deploy(initCode, saltHex);
    const txReceipt = await lockDeploy.wait();
    console.log("Deployed to:", txReceipt.events[0].args[0]);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });