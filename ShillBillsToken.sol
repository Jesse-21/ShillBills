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
//
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ShillBillsToken is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Bonus {
        uint256 firstHalf;
        uint256 secondHalf;
        uint256 claimedTime;
    }

    uint256 public constant BONUS_TIER_1 = 1000 * 10**18;
    uint256 public constant BONUS_TIER_2 = 5000 * 10**18;
    uint256 public constant BONUS_TIER_3 = 10000 * 10**18;
    
    uint256 public constant BONUS_PERCENTAGE_TIER_1 = 5;
    uint256 public constant BONUS_PERCENTAGE_TIER_2 = 10;
    uint256 public constant BONUS_PERCENTAGE_TIER_3 = 15;

    mapping(address => Bonus) public bonuses;

    uint256 public burnRate;
    uint256 public transactionFeeRate;
    uint256 public feeThreshold;
    uint256 public lotteryThreshold;

    uint256 public accumulatedFees;
    mapping(address => bool) public isExcludedFromFees;

    address[] public holders;
    mapping(address => uint256) public lastClaimedTime;
    mapping(address => bool) public claimedFirstHalf;
    mapping(address => bool) public claimedSecondHalf;

    address private _trustedContract;

    event IPFSHashUpdated(string oldHash, string newHash);
    event SettingsUpdated(uint256 burnRate, uint256 transactionFeeRate, uint256 feeThreshold, uint256 lotteryThreshold);
    event IPFSHashLocked(string lockedHash);
    event BuybackAndBurn(uint256 amount);
    event LotteryWinner(address indexed winner, uint256 prizeAmount);
    event BonusAllocated(address indexed buyer, uint256 amount);
    event BonusClaimed(address indexed claimant, uint256 amount);

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable() {
        _mint(address(this), initialSupply);
    }

    function buyTokens(address recipient, uint256 amount) external nonReentrant {
        _transfer(address(this), recipient, amount);
        uint256 bonusAmount = calculateBonus(amount);

        if (bonusAmount > 0) {
            bonuses[recipient].firstHalf = bonuses[recipient].firstHalf.add(bonusAmount.div(2));
            bonuses[recipient].secondHalf = bonuses[recipient].secondHalf.add(bonusAmount.div(2));
            bonuses[recipient].claimedTime = block.timestamp;
        }
    }

    function calculateBonus(uint256 purchaseAmount) internal pure returns (uint256) {
        if (purchaseAmount >= BONUS_TIER_3) {
            return purchaseAmount.mul(BONUS_PERCENTAGE_TIER_3).div(100);
        } else if (purchaseAmount >= BONUS_TIER_2) {
            return purchaseAmount.mul(BONUS_PERCENTAGE_TIER_2).div(100);
        } else if (purchaseAmount >= BONUS_TIER_1) {
            return purchaseAmount.mul(BONUS_PERCENTAGE_TIER_1).div(100);
        } else {
            return 0;
        }
    }

    function claimBonus() external nonReentrant {
        require(bonuses[msg.sender].firstHalf > 0 || bonuses[msg.sender].secondHalf > 0, "No bonus tokens to claim");

        uint256 amountToClaim = 0;

        if (bonuses[msg.sender].firstHalf > 0 && block.timestamp >= bonuses[msg.sender].claimedTime + 14 days) {
            amountToClaim = bonuses[msg.sender].firstHalf;
            bonuses[msg.sender].firstHalf = 0;
        }

        if (bonuses[msg.sender].secondHalf > 0 && block.timestamp >= bonuses[msg.sender].claimedTime + 30 days) {
            amountToClaim = amountToClaim.add(bonuses[msg.sender].secondHalf);
            bonuses[msg.sender].secondHalf = 0;
        }

        require(amountToClaim > 0, "No bonus available for claim at this time");

        _transfer(address(this), msg.sender, amountToClaim);
    }

    // Reentrancy protection and safe arithmetic have been integrated into key functions

    function updateIPFSHash(string memory newHash) external onlyOwner nonReentrant {
        require(!isLocked, "IPFS hash is locked and cannot be updated");
        string memory oldHash = ipfsHash;
        ipfsHash = newHash;
        emit IPFSHashUpdated(oldHash, newHash);
    }

    function lockIPFSHash() external onlyOwner nonReentrant {
        require(!isLocked, "IPFS hash is already locked");
        isLocked = true;
        emit IPFSHashLocked(ipfsHash);
    }

    function updateSettings(
        uint256 _burnRate,
        uint256 _transactionFeeRate,
        uint256 _feeThreshold,
        uint256 _lotteryThreshold
    ) external onlyOwner nonReentrant {
        burnRate = _burnRate;
        transactionFeeRate = _transactionFeeRate;
        feeThreshold = _feeThreshold;
        lotteryThreshold = _lotteryThreshold;

        emit SettingsUpdated(_burnRate, _transactionFeeRate, _feeThreshold, _lotteryThreshold);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _applyTokenomics(_msgSender(), amount);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _applyTokenomics(sender, amount);
        return super.transferFrom(sender, recipient, amount);
    }

    function _applyTokenomics(address sender, uint256 amount) internal {
        if (isExcludedFromFees[sender]) {
            return;
        }

        uint256 burnAmount = amount.mul(burnRate).div(10000);
        uint256 feeAmount = amount.mul(transactionFeeRate).div(10000);

        accumulatedFees = accumulatedFees.add(feeAmount);

        _burn(sender, burnAmount);
        _transfer(sender, address(this), feeAmount);

        if (accumulatedFees >= feeThreshold) {
            _triggerBuybackAndBurn();
        }

        if (accumulatedFees >= lotteryThreshold) {
            _triggerLottery();
        }
    }

    function _triggerBuybackAndBurn() internal nonReentrant {
        uint256 buybackAmount = accumulatedFees;
        accumulatedFees = 0;
        _burn(address(this), buybackAmount);
        emit BuybackAndBurn(buybackAmount);
    }

    function _triggerLottery() internal nonReentrant {
        require(holders.length > 0, "No holders for the lottery");

        uint256 randomIndex = _getRandomNumber() % holders.length;
        address winner = holders[randomIndex];
        uint256 prizeAmount = accumulatedFees;
        accumulatedFees = 0;

        _transfer(address(this), winner, prizeAmount);
        emit LotteryWinner(winner, prizeAmount);
    }

    function _getRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, holders.length)));
    }

    function addHolder(address holder) external onlyOwner {
        holders.push(holder);
    }

    function callExternalContract() public nonReentrant {
        require(msg.sender == _trustedContract, "Caller is not authorized");
    }

    function deposit(uint256 amount) external {
        require(balanceOf(address(this)).add(amount) >= balanceOf(address(this)), "Integer overflow");
        _mint(address(this), amount);
    }

    function secureTransfer(address _to, uint256 _value) external {
        (bool success, ) = _to.call(abi.encodeWithSignature("transfer(uint256)", _value));
        require(success, "External call failed");
    }
}
