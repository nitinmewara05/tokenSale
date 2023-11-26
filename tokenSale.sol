// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract TokenSale {
    address public owner;
    uint public totalSupply;
    uint public tokenPrice;
    uint public saleEndTime;
    uint public initialTotalSupply;
    uint public totalTokensBought;
    uint public totalTokensSold;

    mapping(address => uint) public tokenBalance;
    mapping(address => address) public referrers;
    mapping(address => uint) public referralCount;
    mapping(address => uint) public referralRewards;
    mapping(address => uint) public tokensSoldThisWeek;

    event TokensPurchased(address indexed buyer, uint amount, uint tokensPurchased);
    event TokensSold(address indexed seller, uint amount, uint tokensSold);
    event ReferralReward(address indexed referrer, address indexed buyer, uint tokensRewarded);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor(uint _totalSupply, uint _tokenPrice, uint _saleDuration) {
        owner = msg.sender;
        totalSupply = _totalSupply;
        initialTotalSupply = _totalSupply;
        tokenPrice = _tokenPrice;
        saleEndTime = block.timestamp + _saleDuration;
    }

    function purchaseToken(address _referrer) external payable {
        require(block.timestamp <= saleEndTime, "Token sale has ended");
        require(_referrer != msg.sender, "Cannot use your own address as referrer");
        require(_referrer != address(0), "Referrer address cannot be empty");

        uint tokensToBuy = msg.value / tokenPrice;

        require(tokensToBuy > 0 && tokensToBuy <= getAvailableTokens(), "Invalid token amount");

        // Update referral system
        if (referrers[msg.sender] == address(0)) {
            referrers[msg.sender] = _referrer;
            referralCount[_referrer]++;
            distributeReferralRewards(_referrer);
        }

        // Calculate referral rewards
        if (referralCount[msg.sender] <= 5) {
            uint referralRewardPercentage = 5 - referralCount[msg.sender];
            uint referralReward = (tokensToBuy * referralRewardPercentage) / 100;
            totalSupply -= referralReward;
            referralRewards[referrers[msg.sender]] += referralReward;
            tokenBalance[msg.sender] += tokensToBuy;
            emit ReferralReward(referrers[msg.sender], msg.sender, referralReward);
        }

        totalTokensBought += tokensToBuy;
        tokenBalance[owner] -= tokensToBuy;
        emit TokensPurchased(msg.sender, msg.value, tokensToBuy);
    }

    function sellTokenBack(uint _amount) external {
        require(_amount > 0 && _amount <= tokenBalance[msg.sender], "Invalid token amount");
        require(getAvailableTokens() >= _amount, "Not enough tokens available for sale");

        // Calculate the percentage of tokens sold relative to the initial total supply
        uint tokensSoldPercentage = (_amount * 100) / initialTotalSupply;

        require(tokensSoldPercentage <= 20, "Exceeds maximum sell limit per week");

        uint refundAmount = _amount * tokenPrice;

        tokenBalance[msg.sender] -= _amount;
        totalTokensSold += _amount;
        totalSupply += _amount;
        payable(msg.sender).transfer(refundAmount); // Convert address to address payable
        emit TokensSold(msg.sender, refundAmount, _amount);
    }

    function checkTokenPrice() external view returns (uint) {
        uint tokensAvailable = getAvailableTokens();
        return (initialTotalSupply * tokenPrice) / tokensAvailable;
    }

    function checkTokenBalance(address _buyer) external view returns (uint) {
        return tokenBalance[_buyer];
    }

    function saleTimeLeft() external view returns (uint) {
        if (block.timestamp <= saleEndTime) {
            return saleEndTime - block.timestamp;
        } else {
            return 0;
        }
    }

    function getReferralCount(address _referrer) external view returns (uint) {
        return referralCount[_referrer];
    }

    function getReferralRewards(address _referrer) external view returns (uint) {
        return referralRewards[_referrer];
    }

    function distributeReferralRewards(address _referrer) internal {
        if (_referrer != address(0) && _referrer != owner) {
            uint referralRewardPercentage = 5 - referralCount[_referrer];
            uint referralReward = (totalSupply * referralRewardPercentage) / 100;
            totalSupply -= referralReward;
            referralRewards[referrers[_referrer]] += referralReward;
        }
    }

    function getAvailableTokens() internal view returns (uint) {
        return totalSupply - totalTokensBought + totalTokensSold;
    }

    // Additional functions to transfer ownership and end sale (for emergency purposes)
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function endSale() external onlyOwner {
        saleEndTime = block.timestamp;
    }
}