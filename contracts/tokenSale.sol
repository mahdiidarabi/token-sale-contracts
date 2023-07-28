// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract AtlantisSale is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;

    bool public isLocked;

    IERC20 public tokenToSale;
    uint256 public totalSalingAmount;
    uint256 public totalSold;

    // the following address will be used instead of the native token of the network
    address public asNativeToken = 0x1111111111111111111010101010101010101010;

    mapping(address => bool) public isTokenSupported;
    mapping(address => address) public oracles;
    mapping(address => uint8) public oracleDecimals;

    uint256 public dollarRate;
    uint256 constant dollarUnit = 10 ** 18;

    uint256 immutable public minimumAmountToBuy;

    address payable fundingWallet;

    
    event Buy(address indexed beneficiary, address theToken, uint256 theTokenAmount, uint256 tokenToSaleAmount);

    constructor(
        address _tokenToSale, 
        uint256 _totalToSale, 
        uint256 _dollarRate, 
        uint256 _minimumAmntToBuy,
        address payable _fundWallet, 
        address[] memory _baseTokens,
        address[] memory _chainLinkOracles
    ) {
        require(
            _tokenToSale != address(0),
            "TokenSale: saling token is zero"
        );

        require(
            _totalToSale > 0,
             "TokenSale: amount to sold is zero"
        );

        require(
            _dollarRate > 0,
            "TokenSale: rate is zero"
        );

        require(
            _fundWallet != address(0),
            "TokenSale: fund wallet is zero"
        );

        require(
            _baseTokens.length == _chainLinkOracles.length,
            "TokenSale: legth of tokens and oracles mismatch"
        );

        require(
            _baseTokens.length > 0,
            "TokenSale: no base token"
        );

        require(
            _minimumAmntToBuy > 0,
            "TokenSale: minimum amount to buy is 0"
        );

        tokenToSale = IERC20(_tokenToSale);
        totalSalingAmount = _totalToSale;
        dollarRate = _dollarRate;
        minimumAmountToBuy = _minimumAmntToBuy;
        fundingWallet = _fundWallet;

        for (uint256 i = 0; i < _baseTokens.length; i++) {
            oracles[_baseTokens[i]] = _chainLinkOracles[i];

            oracleDecimals[_baseTokens[i]] = getDecimals(_chainLinkOracles[i]);

            isTokenSupported[_baseTokens[i]] = true;
        }

        isLocked = true;
    }

    /**
     * @dev charge the vesting contract
     */
    function chargeTokenSale(address tokenSaleCharger) external onlyOwner {

        require(tokenToSale.allowance(tokenSaleCharger, address(this)) >= totalSalingAmount,
            "TokenSale: there is not enough token to sale"
        );

        tokenToSale.transferFrom(tokenSaleCharger, address(this), totalSalingAmount);

        isLocked = false;
    }

    /**
     * Returns decimals for oracle contract
     */
    function getDecimals(address theOracle) public view returns (uint8) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(theOracle);

        uint8 decimals = priceFeed.decimals();
        return decimals;
    }

    /**
     * Returns the latest price from oracle contract
     */
    function getLatestPrice(address theOracle) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(theOracle);

        (, int256 price, , , ) = priceFeed.latestRoundData();

        return uint256(price);
    }


    function delivertokenToSales(address beneficiary, uint256 tokenAmount) private {
        tokenToSale.transfer(beneficiary, tokenAmount);
    }

    function forwardBaseToken(address from, address theBaseToken, uint256 theAmount) internal {
        IERC20 ercBaseToken = IERC20(theBaseToken);

        ercBaseToken.transferFrom(from, fundingWallet, theAmount);
    }

    function forwardNativeToken(uint256  theAmount) internal {
        fundingWallet.transfer(theAmount);
    }


    function buytokenToSales(address theBaseToken, address beneficiary, uint256 tokenToSaleAmnt) public nonReentrant payable {

        require(
            !isLocked,
            "TokenSale: locked"
        );

        require(
            isTokenSupported[theBaseToken],
            "TokenSale: this token is not supported"
        );

        require(
            beneficiary != address(0),
            "TokenSale: zero recepient address"
        );

        require(
            tokenToSaleAmnt > 0,
            "TokenSale: zero amount"
        );

        // calculate token amount to be created
        uint256 payInBaseToken = neededBaseToken(theBaseToken, tokenToSaleAmnt);


        if (theBaseToken == asNativeToken) {
            require(
                msg.value >= payInBaseToken,
                "TokenSale: insufficient native token"
            );

            emit Buy(
                beneficiary,
                asNativeToken,
                payInBaseToken,
                tokenToSaleAmnt
            );

            forwardNativeToken(payInBaseToken);

            delivertokenToSales(beneficiary, tokenToSaleAmnt);

        } else {
            IERC20 ercBaseToken = IERC20(theBaseToken);

            require(
                ercBaseToken.allowance(_msgSender(), address(this)) >= payInBaseToken,
                "TokenSale: insufficient base token"
            );

            emit Buy(
                beneficiary,
                theBaseToken,
                payInBaseToken,
                tokenToSaleAmnt
            );

            forwardBaseToken(_msgSender(), theBaseToken, payInBaseToken);

            delivertokenToSales(beneficiary, tokenToSaleAmnt);
        }
    }

    function neededBaseToken(address theBaseToken, uint256 tokenToSaleAmnt) public view returns(uint256){

        require(
            isTokenSupported[theBaseToken],
            "TokenSale: this token is not supported"
        );

        uint256 payInBaseToken = tokenToSaleAmnt.mul(dollarRate);
        uint256 priceOfBaseToken = getLatestPrice(oracles[theBaseToken]);
        
        payInBaseToken = payInBaseToken.mul(uint256(10 ** oracleDecimals[theBaseToken]));
        payInBaseToken = payInBaseToken.div(priceOfBaseToken);
        payInBaseToken = payInBaseToken.div(dollarUnit);

        return payInBaseToken;
    }

     /**
     * @dev the owner of the saling can lock the vesting 
     */
    function lockTokenSale() external onlyOwner {
        isLocked = true;
    }

    /**
     * @dev the owner of the saling can un-lock the vesting 
     */
    function unLockTokenSale() external onlyOwner {
        isLocked = false;
    }

        /**
     * @dev the owner of the vesting can un-lock the vesting 
     */
    function evacuateTokenSale(address stuckToken, address payable reciever, uint256 amount) external onlyOwner {
        require(
            isLocked,
            "TokenSale: evacuation only possible when vesting is locked"
        );

        if (stuckToken == asNativeToken) {

            reciever.transfer(amount);

            // require(
            //     reciever.transfer(amount),
            //     "VestingWallet: couldn't transfer native token"
            // );
        } else {

            IERC20 theToken = IERC20(stuckToken);
            require(
                theToken.transfer(reciever, amount),
                "TokenSale: couldn't transfer token"
            );
        }        

    }
}