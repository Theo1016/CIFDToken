require("dotenv").config();
const { createAlchemyWeb3 } = require("@alch/alchemy-web3");
const { task } = require("hardhat/config");

const {
  API_URL_GOERLI,
  API_URL_OPTIMISM,
  PRIVATE_KEY,
} = process.env;

const web3Goerli = createAlchemyWeb3(API_URL_GOERLI);
const web3Opt = createAlchemyWeb3(API_URL_OPTIMISM);

const networkIDArr = ["Ethereum Goerli:", "Optimism Goerli:"];
const providerArr = [web3Goerli, web3Opt];

task("account", "returns nonce and balance for specified address on multiple networks")
  .addParam("address")
  .setAction(async (taskArgs) => {
    const address = taskArgs.address; // 直接从 taskArgs 中获取地址
    if (!address) {
      console.error("No address provided");
      return;
    }
    const resultArr = [];
    for (let i = 0; i < providerArr.length; i++) {
      try {
        const nonce = await providerArr[i].eth.getTransactionCount(address, "latest");
        const balance = await providerArr[i].eth.getBalance(address);
        resultArr.push([networkIDArr[i], nonce, parseFloat(providerArr[i].utils.fromWei(balance, "ether")).toFixed(2) + "ETH"]);
      } catch (error) {
        console.error(`Error fetching data for network ${networkIDArr[i]}: ${error}`);
        resultArr.push([networkIDArr[i], "Error", "Error"]);
      }
    }
    resultArr.unshift(["NETWORK", "NONCE", "BALANCE"]);
    console.log(resultArr);
  });

module.exports = {
  solidity: "0.8.9",
  networks: {
    hardhat: {},
    goerli: {
      url: API_URL_GOERLI,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    optimism: {
      url: API_URL_OPTIMISM,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
};