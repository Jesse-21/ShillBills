// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// //////////////////////////////////////////////////////////////////////////////
// // ad88888ba   88           88  88  88  88888888ba   88  88  88             //
// //d8"     "8b  88           ""  88  88  88      "8b  ""  88  88             //
// //Y8,          88               88  88  88      ,8P      88  88             //
// //`Y8aaaaa,    88,dPPYba,   88  88  88  88aaaaaa8P'  88  88  88  ,adPPYba,  //
// //  `"""""8b,  88P'    "8a  88  88  88  88""""""8b,  88  88  88  I8[    ""  //
// //        `8b  88       88  88  88  88  88      `8b  88  88  88   `"Y8ba,   //
// //Y8a     a8P  88       88  88  88  88  88      a8P  88  88  88  aa    ]8I  //
// // "Y88888P"   88       88  88  88  88  88888888P"   88  88  88  `"YbbdP"'  //
// //////////////////////////////////////////////////////////////////////////////
// ------------[ www.ShillBills.com  ]------------[ @shillbills]---------------//
// ----[ Rugdox LLC ]------[ support@rugdox.com ]------[ @rugdoxofficial ]-----// 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/math.sol";
contract ShillBillsToken is ERC20, Ownable, ReentrancyGuard {
    using Math for uint256;

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
    ) ERC20(name, symbol) Ownable(msg.sender) {        _mint(address(this), initialSupply);  // Mint the initial supply to the contract itself
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

        uint256 burnAmount = amount * burnRate / 10000;
        uint256 feeAmount = amount * transactionFeeRate / 10000;

        accumulatedFees = accumulatedFees + feeAmount;

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
        bonusTokens[buyer] = bonusTokens[buyer] + amount;
        emit BonusAllocated(buyer, amount);
    }

    // Function for users to claim their bonus tokens in two parts
    function claimBonus() external nonReentrant {
        require(bonusTokens[msg.sender] > 0, "No bonus tokens to claim");

        uint256 amountToClaim;

        // First half can be claimed after 14 days
        if (!claimedFirstHalf[msg.sender] && block.timestamp >= lastClaimedTime[msg.sender] + 14 days) {
            amountToClaim = bonusTokens[msg.sender] / 2;
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

        bonusTokens[msg.sender] = bonusTokens[msg.sender] - amountToClaim;
        lastClaimedTime[msg.sender] = block.timestamp;

        _transfer(address(this), msg.sender, amountToClaim);
    }

    // External contract call with trusted contract verification
    function callExternalContract() public nonReentrant {
        require(msg.sender == _trustedContract, "Caller is not authorized");
        // Execute external contract call
    }
}
