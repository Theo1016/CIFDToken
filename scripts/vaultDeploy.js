const { bytecode } = require("../artifacts/contracts/CIFDToken.sol/CIFDToken.json");
const { encoder, create2Address } = require("../utils/utils.js")

const main = async () => {
    const factoryAddr = "0xEdE0dD72140868A36D5804cD3AAd685A0283E880";
    const foundersWallet = "0x99B3A4b86771181a17b230F90A2e48fCaDfd97C6";
    const investorsWallet = "0x99B3A4b86771181a17b230F90A2e48fCaDfd97C6";
    const ecosystemWallet = "0x99B3A4b86771181a17b230F90A2e48fCaDfd97C6";
    const ownerAddress = "";
    const saltHex = ethers.utils.id("CIFDAQ");
    const initCode = bytecode + encoder(["address", "address", "address","address"], [foundersWallet, investorsWallet, ecosystemWallet,ownerAddress]);

    const create2Addr = create2Address(factoryAddr, saltHex, initCode);
    console.log("precomputed address:", create2Addr);
    
    const Factory = await ethers.getContractFactory("DeterministicDeployFactory");
    const factory = await Factory.attach(factoryAddr);

    const lockDeploy = await factory.deploy(initCode, saltHex, {
      gasLimit: 20000000 
    });
    const txReceipt = await lockDeploy.wait();
    console.log("Deployed to:", lockDeploy.address);
    console.log("Deployed to:", txReceipt.events[0].args[0]);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });