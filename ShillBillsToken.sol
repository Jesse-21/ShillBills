// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//                                                                                                                           
//                                                                                                                            
//   SSSSSSSSSSSSSSS hhhhhhh               iiii  lllllll lllllll BBBBBBBBBBBBBBBBB     iiii  lllllll lllllll                  
// SS:::::::::::::::Sh:::::h              i::::i l:::::l l:::::l B::::::::::::::::B   i::::i l:::::l l:::::l                  
//S:::::SSSSSS::::::Sh:::::h               iiii  l:::::l l:::::l B::::::BBBBBB:::::B   iiii  l:::::l l:::::l                  
//S:::::S     SSSSSSSh:::::h                     l:::::l l:::::l BB:::::B     B:::::B        l:::::l l:::::l                  
//S:::::S             h::::h hhhhh       iiiiiii  l::::l  l::::l   B::::B     B:::::Biiiiiii  l::::l  l::::l     ssssssssss   
//S:::::S             h::::hh:::::hhh    i:::::i  l::::l  l::::l   B::::B     B:::::Bi:::::i  l::::l  l::::l   ss::::::::::s  
// S::::SSSS          h::::::::::::::hh   i::::i  l::::l  l::::l   B::::BBBBBB:::::B  i::::i  l::::l  l::::l ss:::::::::::::s 
//  SS::::::SSSSS     h:::::::hhh::::::h  i::::i  l::::l  l::::l   B:::::::::::::BB   i::::i  l::::l  l::::l s::::::ssss:::::s
//    SSS::::::::SS   h::::::h   h::::::h i::::i  l::::l  l::::l   B::::BBBBBB:::::B  i::::i  l::::l  l::::l  s:::::s  ssssss 
//       SSSSSS::::S  h:::::h     h:::::h i::::i  l::::l  l::::l   B::::B     B:::::B i::::i  l::::l  l::::l    s::::::s      
//            S:::::S h:::::h     h:::::h i::::i  l::::l  l::::l   B::::B     B:::::B i::::i  l::::l  l::::l       s::::::s   
//            S:::::S h:::::h     h:::::h i::::i  l::::l  l::::l   B::::B     B:::::B i::::i  l::::l  l::::l ssssss   s:::::s 
//SSSSSSS     S:::::S h:::::h     h:::::hi::::::il::::::ll::::::lBB:::::BBBBBB::::::Bi::::::il::::::ll::::::ls:::::ssss::::::s
//S::::::SSSSSS:::::S h:::::h     h:::::hi::::::il::::::ll::::::lB:::::::::::::::::B i::::::il::::::ll::::::ls::::::::::::::s 
//S:::::::::::::::SS  h:::::h     h:::::hi::::::il::::::ll::::::lB::::::::::::::::B  i::::::il::::::ll::::::l s:::::::::::ss  
// SSSSSSSSSSSSSSS    hhhhhhh     hhhhhhhiiiiiiiillllllllllllllllBBBBBBBBBBBBBBBBB   iiiiiiiillllllllllllllll  sssssssssss    
//+++++++++++++++++++++++++++++++++++++++[  Digital Pocket Lint For On-Chain Beggers  ]+++++++++++++++++++++++++++++++++++++++                                                                                                                            
//
// www.ShillBills.com | @shillbills | Compliant Utility Exempt  | No Fin Advice | Part of Rugdox Ecosystem (rugdox.com)                                                                               
//                                                                                                      
//  Not for use outside of the Rugdox and ShillBills Ecosystem.  any use by 3rd parties is not in our control.
//  ShillBills and Rugdox LLC cannot be held responsible for any misuse of tokens once they are on-chain and deccentralized
//  We do not and will not give financial advise.  This token was designed to be a utility first token, turn-in for future services,
//  for DAO Voting/Governance, Rugdox Customer Rewards-Feedback and a route of communication with our primary consumers/end-users 
//  to create targeting  products and services by allowing the DAO voting body to be a part of production and follow-up creations. 
//  This is a new way of utilizing a DAO and we expect other organizations to soon follow.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ShillBillsToken is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string public ipfsHash; // IPFS hash where the JSON configuration is stored
    bool public isLocked; // Indicates if the IPFS hash is locked and cannot be updated

    uint256 public burnRate; // Burn rate in basis points (e.g., 10 for 0.1%)
    uint256 public transactionFeeRate; // Fee rate in basis points for buyback and burn (e.g., 10 for 0.1%)
    uint256 public feeThreshold; // Threshold for performing a buyback and burn
    uint256 public lotteryThreshold; // Threshold for triggering the lottery

    uint256 public accumulatedFees; // Accumulated fees from transactions
    mapping(address => bool) public isExcludedFromFees; // Addresses excluded from fees

    address[] public holders; // List of token holders for the lottery
    mapping(address => uint256) public bonusTokens; // Tracks bonus tokens for each user
    mapping(address => uint256) public lastClaimedTime; // Tracks the last time bonus tokens were claimed
    mapping(address => bool) public claimedFirstHalf; // Tracks if the first half of bonus tokens has been claimed
    mapping(address => bool) public claimedSecondHalf; // Tracks if the second half of bonus tokens has been claimed

    address private _trustedContract; // Address of a trusted external contract for external calls

    event IPFSHashUpdated(string oldHash, string newHash);
    event SettingsUpdated(uint256 burnRate, uint256 transactionFeeRate, uint256 feeThreshold, uint256 lotteryThreshold);
    event IPFSHashLocked(string lockedHash);
    event BuybackAndBurn(uint256 amount);
    event LotteryWinner(address indexed winner, uint256 prizeAmount);
    event BonusAllocated(address indexed buyer, uint256 amount);
    event BonusClaimed(address indexed claimant, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        string memory _ipfsHash
    ) ERC20(name, symbol) Ownable() {
        _mint(address(this), initialSupply);  // Mint the initial supply to the contract itself
        ipfsHash = _ipfsHash;  // Set the initial IPFS hash
        isLocked = false;  // Initialize the lock status to false

        // Exclude the contract address from fees (if applicable)
        isExcludedFromFees[address(this)] = true;
    }

    // Function to update the IPFS hash
    function updateIPFSHash(string memory newHash) external onlyOwner nonReentrant {
        require(!isLocked, "IPFS hash is locked and cannot be updated");
        string memory oldHash = ipfsHash;
        ipfsHash = newHash;
        emit IPFSHashUpdated(oldHash, newHash);
    }

    // Function to lock the IPFS hash, preventing further updates
    function lockIPFSHash() external onlyOwner nonReentrant {
        require(!isLocked, "IPFS hash is already locked");
        isLocked = true;
        emit IPFSHashLocked(ipfsHash);
    }

    // Function to update the contract's settings based on external inputs (provided by a front-end or external system)
    function updateSettings(
        uint256 _burnRate,
        uint256 _transactionFeeRate,
        uint256 _feeThreshold,
        uint256 _lotteryThreshold
    ) external onlyOwner nonReentrant {
        require(!isLocked, "Contract settings cannot be updated once IPFS hash is locked");

        burnRate = _burnRate;
        transactionFeeRate = _transactionFeeRate;
        feeThreshold = _feeThreshold;
        lotteryThreshold = _lotteryThreshold;

        emit SettingsUpdated(_burnRate, _transactionFeeRate, _feeThreshold, _lotteryThreshold);
    }

    // Exclude an address from fees (e.g., for ICO funds collection)
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }

    // Override the transfer function to apply tokenomics
    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _applyTokenomics(_msgSender(), amount);
        return super.transfer(recipient, amount);
    }

    // Override the transferFrom function to apply tokenomics
    function transferFrom(address sender, address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _applyTokenomics(sender, amount);
        return super.transferFrom(sender, recipient, amount);
    }

    // Apply tokenomics using the burn rate and transaction fee
    function _applyTokenomics(address sender, uint256 amount) internal {
        // Skip fee application if the sender is excluded
        if (isExcludedFromFees[sender]) {
            return;
        }

        uint256 burnAmount = amount.mul(burnRate).div(10000);
        uint256 feeAmount = amount.mul(transactionFeeRate).div(10000);

        accumulatedFees = accumulatedFees.add(feeAmount);

        _burn(sender, burnAmount);
        _transfer(sender, address(this), feeAmount);

        // Trigger buyback and burn if the threshold is reached
        if (accumulatedFees >= feeThreshold) {
            _triggerBuybackAndBurn();
        }

        // Trigger lottery if the threshold is reached
        if (accumulatedFees >= lotteryThreshold) {
            _triggerLottery();
        }
    }

    // Function to trigger a buyback and burn
    function _triggerBuybackAndBurn() internal nonReentrant {
        uint256 buybackAmount = accumulatedFees;
        accumulatedFees = 0;

        // Implement the buyback logic here (e.g., purchase tokens from a DEX)
        // For simplicity, we burn the tokens directly
        _burn(address(this), buybackAmount);
        emit BuybackAndBurn(buybackAmount);
    }

    // Function to trigger a lottery
    function _triggerLottery() internal nonReentrant {
        require(holders.length > 0, "No holders for the lottery");

        uint256 randomIndex = _getRandomNumber() % holders.length;
        address winner = holders[randomIndex];
        uint256 prizeAmount = accumulatedFees;
        accumulatedFees = 0;

        _transfer(address(this), winner, prizeAmount);
        emit LotteryWinner(winner, prizeAmount);
    }

    // Function to generate a pseudo-random number (for simplicity)
    function _getRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, holders.length)));
    }

    // Function to add a holder (for simplicity, in a real scenario this would be more complex)
    function addHolder(address holder) external onlyOwner {
        holders.push(holder);
    }

    // Function to allocate bonus tokens to a buyer
    function allocateBonus(address buyer, uint256 amount) external onlyOwner {
        bonusTokens[buyer] = bonusTokens[buyer].add(amount);
        emit BonusAllocated(buyer, amount);
    }

    // Function for users to claim their bonus tokens in two parts
    function claimBonus() external nonReentrant {
        require(bonusTokens[msg.sender] > 0, "No bonus tokens to claim");

        uint256 amountToClaim;

        // First half can be claimed after 14 days
        if (!claimedFirstHalf[msg.sender] && block.timestamp >= lastClaimedTime[msg.sender] + 14 days) {
            amountToClaim = bonusTokens[msg.sender].div(2);
            claimedFirstHalf[msg.sender] = true;
            emit BonusClaimed(msg.sender, amountToClaim);
        }

        // Second half can be claimed after 30 days
        if (!claimedSecondHalf[msg.sender] && block.timestamp >= lastClaimedTime[msg.sender] + 30 days) {
            amountToClaim = bonusTokens[msg.sender];
            claimedSecondHalf[msg.sender] = true;
            emit BonusClaimed(msg.sender, amountToClaim);
        }

        require(amountToClaim > 0, "No bonus available for claim at this time");

        bonusTokens[msg.sender] = bonusTokens[msg.sender].sub(amountToClaim);
        lastClaimedTime[msg.sender] = block.timestamp;

        _transfer(address(this), msg.sender, amountToClaim);
    }

    // External contract call with trusted contract verification
    function callExternalContract() public nonReentrant {
        require(msg.sender == _trustedContract, "Caller is not authorized");
        // Execute external contract call
    }
}

    
