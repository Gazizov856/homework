// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB"]
contract VaultMultisig is ReentrancyGuard {
    // ==============================================
    // Storage Variables
    // ==============================================
    
    /// @notice Required number of approvals for execution
    uint256 public quorum;
    
    /// @notice Count of all ETH transfers
    uint256 public ethTransfersCount;

    uint256 public transferID;
    
    /// @notice Count of all ERC20 transfers
    uint256 public erc20TransfersCount;
    
    /// @notice List of current signers
    address[] public currentMultiSigSigners;
    
    /// @notice Mapping of signer status
    mapping(address => bool) public multiSigSigners;
    
    /// @notice ETH transfer requests
    mapping(uint256 => EthTransfer) private ethTransfers;
    
    /// @notice ERC20 transfer requests
    mapping(uint256 => ERC20Transfer) private erc20Transfers;
    
    // ==============================================
    // Struct Definitions
    // ==============================================
    
    struct EthTransfer {
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
        mapping(address => bool) approved;
    }
    
    struct ERC20Transfer {
        address token;
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
        mapping(address => bool) approved;
    }
    
    // ==============================================
    // Errors
    // ==============================================
    
    error SignersArrayCannotBeEmpty();
    error QuorumGreaterThanSigners();
    error QuorumCannotBeZero();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidMultisigSigner();
    error InsufficientBalance(uint256 balance, uint256 desiredAmount);
    error TransferIsAlreadyExecuted(uint256 transferId);
    error SignerAlreadyApproved(address signer);
    error TransferFailed(uint256 transferId);
    error QuorumHasNotBeenReached(uint256 transferId);
    error InvalidTokenAddress();
    error TokenTransferFailed();
    
    // ==============================================
    // Events
    // ==============================================
    
    event EthTransferInitiated(uint256 indexed transferId, address indexed to, uint256 amount);
    event EthTransferApproved(uint256 indexed transferId, address indexed approver);
    event EthTransferExecuted(uint256 indexed transferId);
    
    event ERC20TransferInitiated(uint256 indexed transferId, address indexed token, address indexed to, uint256 amount);
    event ERC20TransferApproved(uint256 indexed transferId, address indexed approver);
    event ERC20TransferExecuted(uint256 indexed transferId);
    
    event MultiSigSignersUpdated();
    event QuorumUpdated(uint256 quorum);
    
    // ==============================================
    // Modifiers
    // ==============================================
    
    modifier onlyMultisigSigner() {
        if (!multiSigSigners[msg.sender]) revert InvalidMultisigSigner();
        _;
    }
    
    // ==============================================
    // Constructor
    // ==============================================
    
    constructor(address[] memory _signers, uint256 _quorum) {
        if (_signers.length == 0) revert SignersArrayCannotBeEmpty();
        if (_quorum > _signers.length) revert QuorumGreaterThanSigners();
        if (_quorum == 0) revert QuorumCannotBeZero();

        for (uint256 i = 0; i < _signers.length; i++) {
            multiSigSigners[_signers[i]] = true;
            currentMultiSigSigners.push(_signers[i]);
        }

        quorum = _quorum;
    }
    
    // ==============================================
    // ETH Transfer Functions
    // ==============================================
    
    function initiateEthTransfer(address _to, uint256 _amount) external onlyMultisigSigner {
        if (_to == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();
        if (address(this).balance < _amount) revert InsufficientBalance(address(this).balance, _amount);

        uint256 transferId = ethTransfersCount++;
        EthTransfer storage transfer = ethTransfers[transferId];
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approved[msg.sender] = true;
        transfer.approvals = 1;

        emit EthTransferInitiated(transferId, _to, _amount);
    }
    
    function approveEthTransfer(uint256 _transferId) external onlyMultisigSigner {
        EthTransfer storage transfer = ethTransfers[_transferId];
        
        if (transfer.executed) revert TransferIsAlreadyExecuted(_transferId);
        if (transfer.approved[msg.sender]) revert SignerAlreadyApproved(msg.sender);

        transfer.approvals++;
        transfer.approved[msg.sender] = true;

        emit EthTransferApproved(_transferId, msg.sender);
    }
    
    function executeEthTransfer(uint256 _transferId) external nonReentrant onlyMultisigSigner {
        EthTransfer storage transfer = ethTransfers[_transferId];
        
        if (transfer.approvals < quorum) revert QuorumHasNotBeenReached(_transferId);
        if (transfer.executed) revert TransferIsAlreadyExecuted(_transferId);
        if (address(this).balance < transfer.amount) {
            revert InsufficientBalance(address(this).balance, transfer.amount);
        }

        transfer.executed = true;
        (bool success, ) = transfer.to.call{value: transfer.amount}("");
        if (!success) revert TransferFailed(_transferId);

        emit EthTransferExecuted(_transferId);
    }
    
    // ==============================================
    // ERC20 Transfer Functions
    // ==============================================
    
    function initiateERC20Transfer(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _transferID
    ) external onlyMultisigSigner {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_to == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();

        transferID=_transferID;
        ERC20Transfer storage transfer = erc20Transfers[transferID];
        
        transfer.token = _token;
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approved[msg.sender] = true;
        transfer.approvals = 1;

        emit ERC20TransferInitiated(transferID, _token, _to, _amount);
    }
    
    function approveERC20Transfer(uint256 _transferApproveId) external onlyMultisigSigner {
        ERC20Transfer storage transfer = erc20Transfers[_transferApproveId];
        
       if (transfer.executed) revert TransferIsAlreadyExecuted(_transferApproveId);
       if (transfer.approved[msg.sender]) revert SignerAlreadyApproved(msg.sender);

        transfer.approvals++;
        transfer.approved[msg.sender] = true;

        emit ERC20TransferApproved(_transferApproveId, msg.sender);
    }
    

    function executeERC20Transfer(uint256 _transferEXEId) external nonReentrant onlyMultisigSigner {
    ERC20Transfer storage transfer = erc20Transfers[_transferEXEId];
    IERC20 token = IERC20(transfer.token);
    if (transfer.executed) revert TransferIsAlreadyExecuted(_transferEXEId);
    if (transfer.approvals < quorum) revert QuorumHasNotBeenReached(_transferEXEId);
    if (transfer.token == address(0)) revert InvalidTokenAddress();

    transfer.executed = true;
    
    
    uint256 contractBalance = token.balanceOf(address(this));
    if (contractBalance < transfer.amount) {
        revert InsufficientBalance(contractBalance, transfer.amount);
    }

    bool success = token.transfer(transfer.to, transfer.amount);
    if (!success) revert TokenTransferFailed();

    emit ERC20TransferExecuted(_transferEXEId);
}
    
    
    // ==============================================
    // View Functions
    // ==============================================
    
    function getEthTransfer(uint256 _transferId) external view returns (
        address to,
        uint256 amount,
        uint256 approvals,
        bool executed
    ) {
        EthTransfer storage transfer = ethTransfers[_transferId];
        return (transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }
    
    function getERC20Transfer(uint256 _transferId) external view returns (
        address token,
        address to,
        uint256 amount,
        uint256 approvals,
        bool executed
    ) {
        ERC20Transfer storage transfer = erc20Transfers[_transferId];
        return (transfer.token, transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }
    
    function hasSignedEthTransfer(uint256 _transferId, address _signer) external view returns (bool) {
        return ethTransfers[_transferId].approved[_signer];
    }
    
    function hasSignedERC20Transfer(uint256 _transferId, address _signer) external view returns (bool) {
        return erc20Transfers[_transferId].approved[_signer];
    }
    
    function getSigners() external view returns (address[] memory) {
        return currentMultiSigSigners;
    }
    
    // ==============================================
    // Fallback Functions
    // ==============================================
    
    receive() external payable {}
}
