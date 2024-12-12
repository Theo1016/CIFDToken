// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CIFDTokenToAnotherChain.sol"; 
contract CIFDToken is ERC20("CIFD Shares", "CIFD"), Ownable {
    address public foundersWallet;
    address public investorsWallet;
    address public ecosystemWallet;
    uint256 public foundersTokens;
    uint256 public unlockTime1Year;
    uint256 public unlockTime2Years;
    uint256 public unlockTime3Years;
    uint256 public unlockTime4Years;
    uint256 public initFounder;
    uint256 public maxSupply;
    uint256 public unlockedTokens; 
    event TokensUnlocked(address beneficiary, uint256 amount);
    address public crossChainAdmin;
    uint64 CROSS_CHAIN_ID;

    constructor(address _foundersWallet, address _investorsWallet, address _ecosystemWallet)
        Ownable(msg.sender) 
    {
        require(_foundersWallet != address(0), "Founder's wallet cannot be the zero address.");
        require(_investorsWallet != address(0), "Investor's wallet cannot be the zero address.");
        require(_ecosystemWallet != address(0), "Ecosystem wallet cannot be the zero address.");
        foundersWallet = _foundersWallet;
        investorsWallet = _investorsWallet;
        ecosystemWallet = _ecosystemWallet;
        unlockTime1Year = block.timestamp + 365 days;
        unlockTime2Years = block.timestamp + 2 * 365 days;
        unlockTime3Years = block.timestamp + 3 * 365 days;
        unlockTime4Years = block.timestamp + 4 * 365 days;
        maxSupply = 500000000 * (10**uint256(decimals()));
        foundersTokens = maxSupply * 20 / 100;//20% founder
        uint256 investorsTokens = maxSupply * 10 / 100;//10% investor
        uint256 ecosystemTokens = maxSupply * 70 / 100;//70% ecosystem
        initFounder = foundersTokens /100; // 1% immediately released
        _mint(foundersWallet, initFounder);
        _mint(investorsWallet, investorsTokens);
        _mint(ecosystemWallet, ecosystemTokens);

        unlockedTokens = initFounder;
        crossChainAdmin = msg.sender;
    }

    function setCrossChainAdmin(address _newAdmin) public onlyOwner {
        crossChainAdmin = _newAdmin;
    }

    function getCCIPAdmin() public view returns (address) {
        return crossChainAdmin;
    }

    function unlockFoundersTokens() public onlyOwner {
        require(block.timestamp >= unlockTime1Year, "Time lock period has not started yet.");
        require(maxSupply > totalSupply(), "Max supply reached.");
        uint256 currentTimestamp = block.timestamp;
        uint256 totalUnlockable = foundersTokens;

        if (currentTimestamp >= unlockTime4Years) {
            totalUnlockable = foundersTokens * 100 / 100;
        } else if (currentTimestamp >= unlockTime3Years) {
            totalUnlockable = foundersTokens * 60 / 100;
        } else if (currentTimestamp >= unlockTime2Years) {
            totalUnlockable = foundersTokens * 30 / 100;
        } else if (currentTimestamp >= unlockTime1Year) {
            totalUnlockable = foundersTokens * 10 / 100;
        } else {
            return;
        }
    
        uint256 amountToUnlock = totalUnlockable - unlockedTokens;
        require(amountToUnlock > 0, "No tokens available to unlock.");

        unlockedTokens += amountToUnlock;
        _mint(foundersWallet, amountToUnlock);
        emit TokensUnlocked(foundersWallet, amountToUnlock);
    }
}