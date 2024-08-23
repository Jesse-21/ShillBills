// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ShillBillsToken is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public feeRate = 10; // 0.1% fee rate in basis points
    uint256 public accumulatedFees; // Accumulated fees for the lotto
    uint256 public feeThreshold = 1000 * 10**18; // Threshold to trigger the lottery
    uint256 public winnerShare = 75; // Winner receives 75% of the accumulated fees

    uint256 public presaleTokensSold;
    uint256 public constant PRESALE_LIMIT = 500000 * 10**18;
    bool public isPresaleActive = true;

    uint256 public tokenPriceInWei = 1000000000000000; // Example: 0.001 ETH per token

    mapping(address => bool) public isExcludedFromFees;
    mapping(address => Bonus) public bonuses;
    mapping(address => bool) public isHolder;
    address[] public holders;

    struct Bonus {
        uint256 firstHalf;
        uint256 secondHalf;
        uint256 claimedTime;
    }

    event FeeCollected(address indexed from, uint256 amount);
    event LotteryWinner(address indexed winner, uint256 prizeAmount);
    event Purchase(address indexed buyer, uint256 amount, bool isPresale);
    event BonusAllocated(address indexed buyer, uint256 bonusAmount);
    event BonusClaimed(address indexed claimer, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        _mint(address(this), 500000 * 10**18); // Initial supply is hardcoded for simplicity
    }

    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        feeRate = newFeeRate;
    }

    function setTokenPrice(uint256 newPriceInWei) external onlyOwner {
        tokenPriceInWei = newPriceInWei;
    }

    function excludeFromFees(address account) external onlyOwner {
        isExcludedFromFees[account] = true;
    }

    function includeInFees(address account) external onlyOwner {
        isExcludedFromFees[account] = false;
    }

    function buyTokens() external payable nonReentrant {
        require(msg.value > 0, "Send ETH to buy tokens");

        uint256 amount = msg.value.div(tokenPriceInWei).mul(10**decimals());
        require(amount > 0, "Not enough ETH sent");

        uint256 fee = amount.mul(feeRate).div(10000);
        uint256 netAmount = amount.sub(fee);

        accumulatedFees = accumulatedFees.add(fee);
        emit FeeCollected(msg.sender, fee);

        uint256 tokensToTransfer = netAmount;
        uint256 bonusAmount = 0;

        // Presale 2-for-1 bonus logic
        if (isPresaleActive && presaleTokensSold < PRESALE_LIMIT) {
            uint256 availableForBonus = PRESALE_LIMIT.sub(presaleTokensSold);

            if (amount > availableForBonus) {
                bonusAmount = availableForBonus;
            } else {
                bonusAmount = amount;
            }

            tokensToTransfer = netAmount.add(bonusAmount);
            presaleTokensSold = presaleTokensSold.add(amount);

            if (presaleTokensSold >= PRESALE_LIMIT) {
                isPresaleActive = false;
            }
        }

        _transfer(address(this), msg.sender, tokensToTransfer);

        // Allocate the bonus tokens
        uint256 calculatedBonus = calculateBonus(amount);
        if (calculatedBonus > 0) {
            bonuses[msg.sender].firstHalf = bonuses[msg.sender].firstHalf.add(calculatedBonus.div(2));
            bonuses[msg.sender].secondHalf = bonuses[msg.sender].secondHalf.add(calculatedBonus.div(2));
            bonuses[msg.sender].claimedTime = block.number; // Block number instead of timestamp
            emit BonusAllocated(msg.sender, calculatedBonus);
        }

        emit Purchase(msg.sender, tokensToTransfer, isPresaleActive);

        // Add recipient to holders list if not already present
        if (!isHolder[msg.sender]) {
            holders.push(msg.sender);
            isHolder[msg.sender] = true;
        }

        // Check if accumulated fees have reached the threshold
        if (accumulatedFees >= feeThreshold) {
            _triggerLottery();
        }
    }

    function calculateBonus(uint256 purchaseAmount) internal pure returns (uint256) {
        return purchaseAmount.mul(10).div(100); // Example: 10% bonus
    }

    function claimBonus() external nonReentrant {
        require(bonuses[msg.sender].firstHalf > 0 || bonuses[msg.sender].secondHalf > 0, "No bonus tokens to claim");

        uint256 amountToClaim = 0;

        // Claim first half after 14 days
        if (bonuses[msg.sender].firstHalf > 0 && block.number >= bonuses[msg.sender].claimedTime + 14 * 5760) {
            amountToClaim = bonuses[msg.sender].firstHalf;
            bonuses[msg.sender].firstHalf = 0;
        }

        // Claim second half after 30 days
        if (bonuses[msg.sender].secondHalf > 0 && block.number >= bonuses[msg.sender].claimedTime + 30 * 5760) {
            amountToClaim = amountToClaim.add(bonuses[msg.sender].secondHalf);
            bonuses[msg.sender].secondHalf = 0;
        }

        require(amountToClaim > 0, "No bonus available for claim at this time");

        _transfer(address(this), msg.sender, amountToClaim);
        emit BonusClaimed(msg.sender, amountToClaim);
    }

    function _applyFeeAndLotto(address sender, address recipient, uint256 amount) internal nonReentrant {
        uint256 fee = 0;

        if (!isExcludedFromFees[sender]) {
            fee = amount.mul(feeRate).div(10000);
            uint256 netAmount = amount.sub(fee);

            accumulatedFees = accumulatedFees.add(fee);
            emit FeeCollected(sender, fee);

            _transfer(sender, address(this), fee);

            if (!isHolder[recipient]) {
                holders.push(recipient);
                isHolder[recipient] = true;
            }

            _transfer(sender, recipient, netAmount); // Use netAmount after fee deduction
        } else {
            _transfer(sender, recipient, amount); // No fee applied, transfer the full amount
        }

        // Check if accumulated fees have reached the threshold
        if (accumulatedFees >= feeThreshold) {
            _triggerLottery();
        }
    }

    function _triggerLottery() internal nonReentrant {
        require(holders.length > 0, "No holders available for lottery");

        uint256 randomIndex = _getRandomNumber() % holders.length;
        address winner = holders[randomIndex];

        uint256 prize = accumulatedFees.mul(winnerShare).div(100);
        accumulatedFees = accumulatedFees.sub(prize);

        _transfer(address(this), winner, prize);
        emit LotteryWinner(winner, prize);
    }

    function _getRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.number, block.difficulty, msg.sender)));
    }

    receive() external payable {
        revert("Direct Ether deposits not allowed. Use buyTokens.");
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

