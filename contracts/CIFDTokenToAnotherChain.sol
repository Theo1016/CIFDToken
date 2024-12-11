// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract CIFDTokenToAnotherChain is ERC20, CCIPReceiver, Ownable {
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    bytes32 private s_lastReceivedMessageId;
    address private s_lastReceivedTokenAddress;
    uint256 private s_lastReceivedTokenAmount;
    string private s_lastReceivedText;

    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;

    error ErrorCase();
    error MessageNotFailed(bytes32 messageId);
    error NothingToWithdraw();
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    IERC20 private s_linkToken;
    bool internal s_simRevert = false;

    address private _ccipAdmin;
    mapping(bytes32 messageId => Client.Any2EVMMessage) public s_messageContents;

    enum ErrorCode {
        RESOLVED,
        FAILED
    }

    struct FailedMessage {
        bytes32 messageId;
        ErrorCode errorCode;
    }

    event TokensUnlocked(address beneficiary, uint256 amount);
    event MessageFailed(bytes32 indexed messageId, bytes reason);
    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        string text,
        address token,
        uint256 tokenAmount
    );
    event MessageRecovered(bytes32 indexed messageId);

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

    function setCCIPAdmin(address admin) public onlyOwner {
        _ccipAdmin = admin;
    }

    modifier onlyCCIPAdmin() {
        require(_ccipAdmin == msg.sender, "Not a CCIP admin");
        _;
    }

    function sendToChain(
        uint64 destinationChainId,
        address receiver,
        uint256 amount,
        bytes memory data
    ) public onlyCCIPAdmin {
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
        )
    {
        try this.processMessage(any2EvmMessage) {
        } catch (bytes memory err) {
            s_failedMessages.set(
                any2EvmMessage.messageId,
                uint256(ErrorCode.FAILED)
            );
            s_messageContents[any2EvmMessage.messageId] = any2EvmMessage;
            emit MessageFailed(any2EvmMessage.messageId, err);
            return;
        }
    }

    function processMessage(
        Client.Any2EVMMessage calldata any2EvmMessage
    )
        external
        onlySelf
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        if (s_simRevert) revert ErrorCase();

        _ccipReceive(any2EvmMessage);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_lastReceivedMessageId = any2EvmMessage.messageId;
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string));
        s_lastReceivedTokenAddress = any2EvmMessage.destTokenAmounts[0].token;
        s_lastReceivedTokenAmount = any2EvmMessage.destTokenAmounts[0].amount;
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            abi.decode(any2EvmMessage.data, (string)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
        );
        address recipient = abi.decode(any2EvmMessage.data, (address));
        _sendCoin(s_lastReceivedTokenAddress, recipient, s_lastReceivedTokenAmount);
    }

    function _sendCoin(
        address tokenAddress,
        address recipient,
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

    function allowlistSource(uint64 sourceChainSelector, address sender) public onlyCCIPAdmin {
        allowlistedSources[sourceChainSelector][sender] = true;
    }

    function getFailedMessages(
        uint256 offset,
        uint256 limit
    ) external view returns (FailedMessage[] memory) {
        uint256 length = s_failedMessages.length();
        uint256 returnLength = (offset + limit > length) ? length - offset : limit;
        FailedMessage[] memory failedMessages = new FailedMessage[](returnLength);

        for (uint256 i = 0; i < returnLength; i++) {
            (bytes32 messageId, uint256 errorCode) = s_failedMessages.at(offset + i);
            failedMessages[i] = FailedMessage(messageId, ErrorCode(errorCode));
        }
        return failedMessages;
    }

    function retryFailedMessage(
        bytes32 messageId,
        address tokenReceiver
    ) external onlyOwner {
        if (s_failedMessages.get(messageId) != uint256(ErrorCode.FAILED))
            revert MessageNotFailed(messageId);

        s_failedMessages.set(messageId, uint256(ErrorCode.RESOLVED));

        Client.Any2EVMMessage memory message = s_messageContents[messageId];
        _transfer(message.destTokenAmounts[0].token, tokenReceiver, message.destTokenAmounts[0].amount);
        emit MessageRecovered(messageId);
    }

    function withdraw(address beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        (bool sent,) = beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

    function withdrawToken(address beneficiary, address token) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();

        _transfer(token, beneficiary, amount);
    }
}