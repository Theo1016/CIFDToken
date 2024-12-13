const { bytecode } = require("../artifacts/contracts/CIFDToken.sol/CIFDToken.json");
const { encoder, create2Address } = require("../utils/utils.js")

const main = async () => {
    const factoryAddr = process.env.FACTORY_ADDR;
    const foundersWallet = process.env.FOUNDERS_WALLET;
    const investorsWallet = process.env.INVESTORS_WALLET;
    const ecosystemWallet = process.env.ECOSYSTEM_WALLET;
    const owner = process.env.OWNER;
    const saltHex = ethers.utils.id("CIFDAQ");
    const initCode = bytecode + encoder(["address"], [foundersWallet])+encoder(["address"], [investorsWallet])+ encoder(["address"], [ecosystemWallet])+ encoder(["address"], [owner]);

    const create2Addr = create2Address(factoryAddr, saltHex, initCode);
    console.log("precomputed address:", create2Addr);
    
    const Factory = await ethers.getContractFactory("DeterministicDeployFactory");
    const factory = await Factory.attach(factoryAddr);

    const lockDeploy = await factory.deploy(initCode, saltHex);
    const txReceipt = await lockDeploy.wait();
    const deployedEvent = txReceipt.events?.find(event => event.event === 'Deploy');

    if (deployedEvent) {
        console.log("Deployed contract address:", deployedEvent.args.addr);
    } else {
        console.error("Deployed event not found in transaction receipt");
    }
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });