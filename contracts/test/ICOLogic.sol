// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.4;

import "../tokenSale/tokenSale.sol";

contract ICOLogic is TokenSale {
    function initialize(
        address _tokenToSale, 
        uint256 _totalToSale, 
        uint256 _dollarRate, 
        uint256 _minimumAmntToBuy,
        address payable _fundWallet, 
        address[] memory _baseTokens,
        address[] memory _chainLinkOracles
    ) public initializer {
        TokenSale.__TokenSale_init(
            _tokenToSale,
            _totalToSale,
            _dollarRate,
            _minimumAmntToBuy,
            _fundWallet,
            _baseTokens,
            _chainLinkOracles
        );
    }
}