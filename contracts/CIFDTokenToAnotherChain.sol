// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract CIFDTokenToAnotherChain is ERC20,CCIPReceiver,Ownable{
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    address private s_lastReceivedTokenAddress; // Store the last received token address.
    uint256 private s_lastReceivedTokenAmount; // Store the last received amount.
    string private s_lastReceivedText; // Store the last received text.
   

    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;
    error ErrorCase(); // Used when simulating a revert during message processing.
    IERC20 private s_linkToken;
    bool internal s_simRevert = false;

    address private _ccipAdmin;
    // The message contents of failed messages are stored here.
    mapping(bytes32 messageId => Client.Any2EVMMessage contents)
        public s_messageContents;


    enum ErrorCode {
        // RESOLVED is first so that the default value is resolved.
        RESOLVED,
        // Could have any number of error codes here.
        FAILED
    }    
    struct FailedMessage {
        bytes32 messageId;
        ErrorCode errorCode;
    }

    event TokensUnlocked(address beneficiary, uint256 amount);
    event MessageFailed(bytes32 indexed messageId, bytes reason);
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string text, // The text that was received.
        address token, // The token address that was transferred.
        uint256 tokenAmount // The token amount that was transferred.
    );
    

     IRouterClient private router;
     address private linkTokenAddress; 
 
     event CcipSend(address indexed sender, address indexed receiver, uint256 amount, bytes data, uint64 destinationChainId);

    
     constructor(address _router, address _link)
     ERC20("CIFD Shares", "CIFD") 
     CCIPReceiver(_router) 
     Ownable(msg.sender) 
     {
         router = IRouterClient(_router);
         linkTokenAddress = _link;
    }
    function getCCIPAdmin() public view returns (address) {
        return _ccipAdmin;
    }

    function setCCIPAdmin(address admin) public onlyOwner{
        _ccipAdmin = admin;
    }

    modifier onlyCCIPAdmin() {
        require(_ccipAdmin==msg.sender, "Not a CCIP admin");
        _;
    }

    function sendToChain(
        uint64 destinationChainId,
        address receiver,
        uint256 amount,
        bytes memory data
    ) public onlyCCIPAdmin  {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](1),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: linkTokenAddress
        });

        message.tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(this),
            amount: amount
        });

        uint256 fees = router.getFee(destinationChainId, message);
        require(ERC20(linkTokenAddress).balanceOf(address(this)) >= fees, "Not enough LINK balance");
        ERC20(linkTokenAddress).approve(address(router), fees);

        bytes32 messageId = router.ccipSend(destinationChainId, message);
        emit CcipSend(msg.sender, receiver, amount, data, destinationChainId);
    }

    function ccipReceive(
        Client.Any2EVMMessage calldata any2EvmMessage
    )
        external
        override
        onlyRouter
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        /* solhint-disable no-empty-blocks */
        try this.processMessage(any2EvmMessage) {
            // Intentionally empty in this example; no action needed if processMessage succeeds
        } catch (bytes memory err) {
            // Could set different error codes based on the caught error. Each could be
            // handled differently.
            s_failedMessages.set(
                any2EvmMessage.messageId,
                uint256(ErrorCode.FAILED)
            );
            s_messageContents[any2EvmMessage.messageId] = any2EvmMessage;
            // Don't revert so CCIP doesn't revert. Emit event instead.
            // The message can be retried later without having to do manual execution of CCIP.
            emit MessageFailed(any2EvmMessage.messageId, err);
            return;
        }
    }

    /// @notice Serves as the entry point for this contract to process incoming messages.
    /// @param any2EvmMessage Received CCIP message.
    /// @dev Transfers specified token amounts to the owner of this contract. This function
    /// must be external because of the  try/catch for error handling.
    /// It uses the `onlySelf`: can only be called from the contract.
    function processMessage(
        Client.Any2EVMMessage calldata any2EvmMessage
    )
        external
        onlySelf
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        // Simulate a revert for testing purposes
        if (s_simRevert) revert ErrorCase();

        _ccipReceive(any2EvmMessage); // process the message - may revert as well
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text
        // Expect one token to be transferred at once, but you can transfer several tokens.
        s_lastReceivedTokenAddress = any2EvmMessage.destTokenAmounts[0].token;
        s_lastReceivedTokenAmount = any2EvmMessage.destTokenAmounts[0].amount;
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            abi.decode(any2EvmMessage.data, (string)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
        );
        address recipient = abi.decode(any2EvmMessage.data, (address));
        _transfer(s_lastReceivedTokenAddress, recipient, s_lastReceivedTokenAmount);
    }

    function _transfer(
    address tokenAddress,
    address payable recipient,
    uint256 amount
    ) internal {
    if (tokenAddress == address(this)) {
        _transferERC20(tokenAddress, recipient, amount);
    } else {
        IERC20(tokenAddress).transfer(recipient, amount);
    }
    }

    function _transferERC20(
    address tokenAddress,
    address payable recipient,
    uint256 amount
    ) internal {
    IERC20(tokenAddress).transfer(recipient, amount);
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Caller is not the contract itself");
        _;
    }
    mapping(uint64 => mapping(address => bool)) public allowlistedSources;

    modifier onlyAllowlisted(uint64 sourceChainSelector, address sender) {
    require(allowlistedSources[sourceChainSelector][sender], "Source chain or sender is not allowlisted");
    _;
    }

    function allowlistSource(uint64 sourceChainSelector, address sender) public onlyCCIPAdmin  {
    allowlistedSources[sourceChainSelector][sender] = true;
    }

    function getFailedMessages(
        uint256 offset,
        uint256 limit
    ) external view returns (FailedMessage[] memory) {
        uint256 length = s_failedMessages.length();

        // Calculate the actual number of items to return (can't exceed total length or requested limit)
        uint256 returnLength = (offset + limit > length)
            ? length - offset
            : limit;
        FailedMessage[] memory failedMessages = new FailedMessage[](
            returnLength
        );

        // Adjust loop to respect pagination (start at offset, end at offset + limit or total length)
        for (uint256 i = 0; i < returnLength; i++) {
            (bytes32 messageId, uint256 errorCode) = s_failedMessages.at(
                offset + i
            );
            failedMessages[i] = FailedMessage(messageId, ErrorCode(errorCode));
        }
        return failedMessages;
    }
}