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
//S::::SSSS          h::::::::::::::hh   i::::i  l::::l  l::::l   B::::BBBBBB:::::B  i::::i  l::::l  l::::l ss:::::::::::::s 
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
//
//

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ShillBillsToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public burnRate; // Burn rate in basis points (e.g., 10 for 0.1%)
    uint256 public transactionFeeRate; // Fee rate in basis points for buyback and burn (e.g., 10 for 0.1%)
    uint256 public feeThreshold; // Threshold for performing a buyback and burn
    uint256 public lotteryThreshold; // Threshold for triggering the lottery
    uint256 public perTransactionLimit = 10 ether; // Maximum purchase per transaction
    uint256 public perAddressLimit = 50 ether; // Maximum purchase per address
    uint256 public globalSaleLimit = 1000 ether; // Maximum sale limit in a timeframe
    uint256 public totalSales; // Tracks total sales in the pre-sale
    uint256 public rate; // Tokens per ETH

    address public buybackWallet; // Wallet for collecting fees before buyback
    uint256 public accumulatedFees; // Accumulated fees for buyback or lottery

    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isKYCCompleted;
    mapping(address => uint256) public addressPurchases;
    mapping(address => uint256) public lastPurchaseTime;

    struct Contribution {
        uint256 ethAmount;
        uint256 tokenAmount;
        uint256 bonusTokens;
        bool initialClaimed;
        bool bonusClaimed14;
        bool bonusClaimed30;
        uint256 initialClaimTime;
    }

    mapping(address => Contribution) public contributions;
    address[] public holders;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 bonus);
    event BonusTokensClaimed(address indexed claimant, uint256 amount, string period);
    event BuybackAndBurn(uint256 amount);
    event LotteryWinner(address indexed winner, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _rate,
        uint256 _burnRate,
        uint256 _transactionFeeRate,
        uint256 _feeThreshold,
        uint256 _lotteryThreshold,
        address _buybackWallet
    ) ERC20(name, symbol) {
        _mint(address(this), initialSupply); // Mint all tokens to contract
        rate = _rate;
        burnRate = _burnRate;
        transactionFeeRate = _transactionFeeRate;
        feeThreshold = _feeThreshold;
        lotteryThreshold = _lotteryThreshold;
        buybackWallet = _buybackWallet;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "Not whitelisted");
        _;
    }

    modifier kycVerified() {
        require(isKYCCompleted[msg.sender], "KYC not completed");
        _;
    }

    modifier botControlled(uint256 amount) {
        require(amount <= perTransactionLimit, "Exceeds per transaction limit");
        require(addressPurchases[msg.sender] + amount <= perAddressLimit, "Exceeds per address limit");
        require(block.timestamp >= lastPurchaseTime[msg.sender] + 1 minutes, "Rate limit exceeded");
        require(totalSales + amount <= globalSaleLimit, "Global sale limit exceeded");
        _;
        lastPurchaseTime[msg.sender] = block.timestamp;
        addressPurchases[msg.sender] += amount;
        totalSales += amount;
    }

    function whitelistAddress(address _user) external onlyOwner {
        isWhitelisted[_user] = true;
    }

    function removeWhitelistAddress(address _user) external onlyOwner {
        isWhitelisted[_user] = false;
    }

    function markAsKYCCompleted(address _user) external onlyOwner {
        isKYCCompleted[_user] = true;
    }

    function contributePreSale() external payable onlyWhitelisted kycVerified botControlled(msg.value) nonReentrant {
        uint256 tokenAmount = msg.value * rate;
        uint256 bonusPercent = calculateBonus(msg.value);
        uint256 bonusTokens = (tokenAmount * bonusPercent) / 100;

        contributions[msg.sender] = Contribution({
            ethAmount: msg.value,
            tokenAmount: tokenAmount,
            bonusTokens: bonusTokens,
            initialClaimed: false,
            bonusClaimed14: false,
            bonusClaimed30: false,
            initialClaimTime: block.timestamp + 1 days
        });

        emit TokensPurchased(msg.sender, tokenAmount, bonusTokens);
    }

    function calculateBonus(uint256 ethSpent) internal pure returns (uint256) {
        if (ethSpent >= 10 ether) {
            return 10; // 10% bonus
        } else if (ethSpent >= 5 ether) {
            return 5; // 5% bonus
        } else if (ethSpent >= 1 ether) {
            return 2; // 2% bonus
        } else {
            return 0.5; // 0.5% bonus for small purchases
        }
    }

    function claimTokens() external nonReentrant {
        Contribution storage c = contributions[msg.sender];
        require(block.timestamp >= c.initialClaimTime, "Tokens not ready for claim");
        require(!c.initialClaimed, "Tokens already claimed");

        c.initialClaimed = true;
        _transfer(address(this), msg.sender, c.tokenAmount);
    }

    function claimBonusTokens(uint256 claimType) external nonReentrant {
        Contribution storage c = contributions[msg.sender];
        uint256 claimableAmount;

        if (claimType == 14 && block.timestamp >= c.initialClaimTime + 14 days) {
            require(!c.bonusClaimed14, "First bonus already claimed");
            c.bonusClaimed14 = true;
            claimableAmount = c.bonusTokens / 2;
        } else if (claimType == 30 && block.timestamp >= c.initialClaimTime + 30 days) {
            require(!c.bonusClaimed30, "Second bonus already claimed");
            c.bonusClaimed30 = true;
            claimableAmount = c.bonusTokens / 2;
        } else {
            revert("Invalid claim type or time");
        }

        _transfer(address(this), msg.sender, claimableAmount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _applyTokenomics(_msgSender(), amount);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _applyTokenomics(sender, amount);
        return super.transferFrom(sender, recipient, amount);
    }

    function _applyTokenomics(address sender, uint256 amount) internal {
        uint256 burnAmount = (amount * burnRate) / 10000;
        uint256 feeAmount = (amount * transactionFeeRate) / 10000;

        accumulatedFees += feeAmount;

        _burn(sender, burnAmount);
        _transfer(sender, address(this), feeAmount);

        if (accumulatedFees >= feeThreshold) {
            _triggerBuybackAndBurn();
        } else if (accumulatedFees >= lotteryThreshold) {
            _triggerLottery();
        }
    }

    function _triggerBuybackAndBurn() internal nonReentrant {
        require(accumulatedFees >= feeThreshold, "Insufficient fees for buyback");

        uint256 buybackAmount = accumulatedFees;
        accumulatedFees = 0;

        _transfer(address(this), buybackWallet, buybackAmount);
        emit BuybackAndBurn(buybackAmount);
    }

    function _triggerLottery() internal nonReentrant {
        require(accumulatedFees >= lotteryThreshold, "Insufficient fees for lottery");

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

    function setBurnRate(uint256 newBurnRate) external onlyOwner {
        require(newBurnRate <= 1000, "Burn rate too high"); // Max 10%
        burnRate = newBurnRate;
    }

    function setTransactionFeeRate(uint256 newTransactionFeeRate) external onlyOwner {
        require(newTransactionFeeRate <= 1000, "Transaction fee rate too high"); // Max 10%
        transactionFeeRate = newTransactionFeeRate;
    }

    function setFeeThreshold(uint256 newFeeThreshold) external onlyOwner {
        feeThreshold = newFeeThreshold;
    }

    function setLotteryThreshold(uint256 newLotteryThreshold) external onlyOwner {
        lotteryThreshold = newLotteryThreshold
    
