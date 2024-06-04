// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


////////////////////
// Errors
////////////////////
error InsufficientETH();
error ProposalNotApproved();
error UnauthorizedAccess();
error InsufficientShares();
error ZeroAddress();
error InvalidSharesAmount();
error AlreadyApproved();
error FailedTransfer();
error ProposalNotFound();
error NotEnoughVotes();
error AlreadyVoted();
error MemberExists();

////////////////////
// Contract
////////////////////
contract MolochRageQuit {
    ///////////////////
    // Type Declarations
    ///////////////////
    struct Proposal {
        address proposer;
        uint256 ethAmount;
        uint256 shareAmount;
        uint256 votes;
        bool approved;
        mapping(address => bool) voted;
    }

    ///////////////////
    // State Variables
    ///////////////////
    uint256 public totalShares;
    uint256 public totalEth;
    uint256 public proposalCount;
    uint256 public quorum;
    mapping(address => uint256) public shares;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;

    ///////////////////
    // Events
    ///////////////////
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        uint256 ethAmount,
        uint256 shareAmount
    );
    event ProposalApproved(uint256 proposalId, address approver);
    event SharesExchanged(
        address proposer,
        uint256 ethAmount,
        uint256 shareAmount
    );
    event RageQuit(address member, uint256 shareAmount, uint256 ethAmount);
    event MemberAdded(address member);
    event MemberRemoved(address member);
    event Voted(uint256 proposalId, address voter);
    event Withdrawal(address owner, uint256 amount);

    ///////////////////
    // Modifiers
    ///////////////////
    modifier onlyMember() {
        if (!members[msg.sender]) {
            revert UnauthorizedAccess();
        }
        _;
    }

    ///////////////////
    // Constructor
    ///////////////////
    constructor(uint256 _quorum) {
        members[msg.sender] = true;
        quorum = _quorum;
    }

    ///////////////////
    // External Functions
    ///////////////////

    /**
     * @dev Propose to acquire shares for ETH.
     * @param ethAmount The amount of ETH to exchange for shares.
     * @param shareAmount The amount of shares to acquire.
     * Requirements:
     * - `ethAmount` must be greater than 0.
     * - `shareAmount` must be greater than 0.
     * - should revert with `InvalidSharesAmount` if either `ethAmount` or `shareAmount` is 0.
     * - Increment the proposal count.
     * - Create a new proposal
     * Emits a `ProposalCreated` event.
     */
    function propose(uint256 ethAmount, uint256 shareAmount) external {
        if (ethAmount == 0 || shareAmount == 0) {
            revert InvalidSharesAmount();
        }

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.proposer = msg.sender;
        proposal.ethAmount = ethAmount;
        proposal.shareAmount = shareAmount;

        emit ProposalCreated(proposalCount, msg.sender, ethAmount, shareAmount);
    }

    /**
     * @dev Vote on a proposal.
     * @param proposalId The ID of the proposal to vote on.
     * Requirements:
     * - Revert with `ProposalNotFound` if the proposal does not exist.
     * - Revert with `AlreadyVoted` if the caller has already voted on the proposal.
     * - Caller must be a member.
     * - Proposal must exist.
     * - Caller must not have already voted on the proposal.
     * - Increment the proposal's vote count.
     * - Mark the caller as having voted on the proposal.
     * - If the proposal has enough votes, mark it as approved.
     * Emits a `Voted` event.
     * Emits a `ProposalApproved` event if the proposal is approved.
     */
    function vote(uint256 proposalId) external onlyMember {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.proposer == address(0)) {
            revert ProposalNotFound();
        }
        if (proposal.voted[msg.sender]) {
            revert AlreadyVoted();
        }

        proposal.votes++;
        proposal.voted[msg.sender] = true;

        emit Voted(proposalId, msg.sender);

        if (proposal.votes >= quorum) {
            proposal.approved = true;
            emit ProposalApproved(proposalId, msg.sender);
        }
    }

    /**
     * @dev Exchange ETH for shares after approval.
     * @param proposalId The ID of the approved proposal.
     * Requirements:
     * - The caller must be the proposer of the proposal.
     * - The proposal must be approved.
     * - The amount of ETH sent must match the proposal's ETH amount.
     * Emits a `SharesExchanged` event.
     */
    function exchangeShares(uint256 proposalId) external payable onlyMember {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.proposer != msg.sender || !proposal.approved) {
            revert ProposalNotApproved();
        }
        if (msg.value < proposal.ethAmount) {
            revert InsufficientETH();
        }

        totalEth += msg.value;
        totalShares += proposal.shareAmount;
        shares[msg.sender] += proposal.shareAmount;

        emit SharesExchanged(msg.sender, msg.value, proposal.shareAmount);
    }

    /**
     * @dev Rage quit and exchange shares for ETH.
     * Requirements:
     * - The caller must have shares and must be a member.
     * - Calculate the amount of ETH to return to the caller.
     * - Update the total shares and total ETH.
     * - Mark the caller as having 0 shares.
     * - Transfer the ETH after calculating the share of eth to send to the caller.
     * - Revert with `FailedTransfer` if the transfer fails.
     * Emits a `RageQuit` event.
     */
    function rageQuit() external onlyMember {
        uint256 memberShares = shares[msg.sender];
        if (memberShares == 0) {
            revert InsufficientShares();
        }
        uint256 ethAmount = (memberShares * totalEth) / totalShares;
        totalShares -= memberShares;
        totalEth -= ethAmount;
        shares[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: ethAmount}("");
        if (!sent) {
            revert FailedTransfer();
        }
        emit RageQuit(msg.sender, memberShares, ethAmount);
    }

    /**
     * @dev Add a new member to the DAO.
     * @param newMember The address of the new member.
     * Requirements:
     * - Only callable by the owner.
     * - The address must not already be a member.
     * - Mark the address as a member.
     * Emits a `MemberAdded` event.
     */
    function addMember(address newMember) external  {
        if (members[newMember]) {
            revert MemberExists();
        }
        members[newMember] = true;
        emit MemberAdded(newMember);
    }

    /**
     * @dev Remove a member from the DAO.
     * @param member The address of the member to remove.
     * Requirements:
     * - Only callable by the owner.
     * - Mark the member as not a member.
     * Emits an `MemberRemoved` event.
     */
    function removeMember(address member) external {
        members[member] = false;
        emit MemberRemoved(member);
    }
}
