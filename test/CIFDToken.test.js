const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CIFDToken", function () {
  let cifdToken;
  let owner;
  let founder;
  let investor;
  let ecosystem;
  let founderWallet;
  let investorsWallet;
  let ecosystemWallet;

  beforeEach(async function () {
    const CIFDToken = await ethers.getContractFactory("CIFDToken");
    [owner, founder, investor, ecosystem] = await ethers.getSigners();

    cifdToken = await CIFDToken.deploy(founder.address, investor.address, ecosystem.address);
    await cifdToken.deployed();
    founderWallet = founder.address;
    investorsWallet = investor.address;
    ecosystemWallet = ecosystem.address;
  });

  it("Should set the right owner", async function () {
    expect(await cifdToken.owner()).to.equal(owner.address);
    console.log("Owner:", await cifdToken.owner());
  });

  it("Should assign the initial founder, investor, and ecosystem tokens", async function () {
    const totalSupply = await cifdToken.totalSupply();
    const foundersTokens = totalSupply.mul(20).div(100).div(100);
    const investorsTokens = totalSupply.mul(10).div(100);
    const ecosystemTokens = totalSupply.mul(70).div(100);

    const founderInitialBalance = await cifdToken.balanceOf(founderWallet);
    const investorInitialBalance = await cifdToken.balanceOf(investorsWallet);
    const ecosystemInitialBalance = await cifdToken.balanceOf(ecosystemWallet);

    console.log("Total Supply:", totalSupply.toString());
    console.log("Founder's Initial Tokens:", founderInitialBalance.toString());
    console.log("Investor's Initial Tokens:", investorInitialBalance.toString());
    console.log("Ecosystem's Initial Tokens:", ecosystemInitialBalance.toString());
  });

  it("Should unlock founders tokens after 1-5 year", async function () {
    await network.provider.send("evm_setNextBlockTimestamp", [(await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60]);
    await cifdToken.connect(owner).unlockFoundersTokens();

    const totalSupply = await cifdToken.totalSupply();
    const foundersTokens = await cifdToken.foundersTokens();
    const founderBalanceAfterOneYear = await cifdToken.balanceOf(founderWallet);
    console.log("Founder's Balance After 1 Year:", founderBalanceAfterOneYear.toString());
    console.log("Total Supply:", totalSupply.toString());
    console.log("Founders Tokens:", foundersTokens.toString());

    console.log("Should unlock founders tokens after 2 year");
    await network.provider.send("evm_setNextBlockTimestamp", [(await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60]);
    await cifdToken.connect(owner).unlockFoundersTokens();  
    const totalSupply2 = await cifdToken.totalSupply();
    const foundersTokens2 = await cifdToken.foundersTokens();
    const founderBalanceAfterTwoYear = await cifdToken.balanceOf(founderWallet);
    console.log("Founder's Balance After 2 Year:", founderBalanceAfterTwoYear.toString());
    console.log("Total Supply 2:", totalSupply2.toString());
    console.log("Founders Tokens 2:", foundersTokens2.toString());

    console.log("Should unlock founders tokens after 3 year");

    await network.provider.send("evm_setNextBlockTimestamp", [(await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60]);
    await cifdToken.connect(owner).unlockFoundersTokens();
    const totalSupply3 = await cifdToken.totalSupply();
    const foundersTokens3 = await cifdToken.foundersTokens();
    const founderBalanceAfterThreeYear = await cifdToken.balanceOf(founderWallet);
    console.log("Founder's Balance After 3 Year:", founderBalanceAfterThreeYear.toString());
    console.log("Total Supply:", totalSupply3.toString());
    console.log("Founders Tokens:", foundersTokens3.toString());

    console.log("Should unlock founders tokens after 4 year");

    await network.provider.send("evm_setNextBlockTimestamp", [(await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60]);
    await cifdToken.connect(owner).unlockFoundersTokens();

    const totalSupply4 = await cifdToken.totalSupply();
    const foundersTokens4 = await cifdToken.foundersTokens();
    const founderBalanceAfterFourYear = await cifdToken.balanceOf(founderWallet);
    console.log("Founder's Balance After 4 Year:", founderBalanceAfterFourYear.toString());
    console.log("Total Supply:", totalSupply4.toString());
    console.log("Founders Tokens:", foundersTokens4.toString());

    console.log("Should unlock founders tokens after 5 year");

    await network.provider.send("evm_setNextBlockTimestamp", [(await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60]);
    await cifdToken.connect(owner).unlockFoundersTokens();

    const totalSupply5 = await cifdToken.totalSupply();
    const foundersTokens5 = await cifdToken.foundersTokens();
    const founderBalanceAfterFiveYear = await cifdToken.balanceOf(founderWallet);
    console.log("Founder's Balance After 5 Year:", founderBalanceAfterFiveYear.toString());
    console.log("Total Supply:", totalSupply5.toString());
    console.log("Founders Tokens:", foundersTokens5.toString());
  });

});