// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @notice ERC1155 token upgraded with three states
/// @notice The purpose is to separate the phase of mint from the one of token transfer to secure the price during this time
/// @notice You can also swith between closed/open minting and closed/open market
/// @notice Once you have decided to open the market it is impossible to go back to mint
/// @author Rems000

contract 3StatesERC1155 is Ownable, ERC1155 {
    /// @dev TOKEN_PRICE is the amount ncessary to mint the project
    /// @dev TRUNC_URI is a truncated uri that will be concatened with tokenId and .json for NFT marketplace
    /// @dev sft_state is the variable that defines the actual state of the contract
    /// @dev MINT_CLOSED_FOREVER is a bool variable quite meaningful
    uint256 public TOKEN_PRICE;
    string public TRUNC_URI;

    enum SFT_STATE {
        CLOSED,
        MINT,
        OPEN_MARKET
    }
    SFT_STATE public sft_state;
    bool public MINT_CLOSED_FOREVER;

    event StateChange(string newState);

    event ProjectMinted(address to, uint256 amount);

    /// @dev link is the file you want your token to be linked to, check openzeppelin for more details
    /// @dev The constructor init also the base uri for nft marketplaces and set parameters sft_state, MINT_CLOSED_FOREVER
    /// @dev and TOKEN_PRICE to inital values
    constructor()
        ERC1155(
            "ipfs://.../{id}.json"
        )
    {
        TRUNC_URI = "ipfs:/.../";
        sft_state = SFT_STATE.CLOSED;
        MINT_CLOSED_FOREVER = false;
        TOKEN_PRICE = 0;
    }

    /// @notice Override uri function for NFT marketplace
    /// @param _tokenId Id of the token whose uri is requested
    /// @return string uri of the json file the token is linked to
    function uri(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(TRUNC_URI, Strings.toString(_tokenId), ".json")
            );
    }

    /// @notice Set a new base uri for the tokens
    /// @param _newUri New uri for the json files
    /// @dev As we are using a different format for NFT marketplace the function call internal '_setURI' function
    ///      and also changes the base uri used for NFT marketplace
    function setUri(string calldata _newUri) public onlyOwner {
        _setURI(string.concat(_newUri, "{id}.json"));
        TRUNC_URI = _newUri;
    }


    /// @notice Mint the full project
    /// @dev Check the value of the message corresponds to the mint price of the project
    /// @param _amount The amount of token the user want to mint
    function mint_project(uint256 _amount) public payable {
        require(msg.value >= TOKEN_PRICE * _amount);
        _mint(msg.sender, 1, _amount, "");
        _mint(msg.sender, 2, _amount, "");
        _mint(msg.sender, 3, _amount, "");
        _mint(msg.sender, 4, _amount, "");
        emit ProjectMinted(msg.sender, _amount);
    }

    /// @notice Allows token tranfer but closes mint forever
    /// @dev This is the only function that modifies the MINT_CLOSED_FOREVER parameter
    function setStateOpen() public onlyOwner {
        if (!MINT_CLOSED_FOREVER) {
            MINT_CLOSED_FOREVER = true;
        }
        sft_state = SFT_STATE.OPEN_MARKET;
        emit StateChange("OPEN_MARKET");
    }

    /// @notice Allows mint but not the token transfer
    /// @dev Checks the MINT_CLOSED_FOREVER parameter has not been set on true
    function setStateMint() public onlyOwner {
        require(!MINT_CLOSED_FOREVER);
        sft_state = SFT_STATE.MINT;
        emit StateChange("MINT");
    }

    /// @notice Closes both mint and token transfer
    function setStateClosed() public onlyOwner {
        sft_state = SFT_STATE.CLOSED;
        emit StateChange("CLOSED");
    }

    /// @notice Check if we allow mint, token transfer or none before taking action
    /// @dev As the minting of token is a transfer from the zero address the function checks this parameter
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        from == address(0)
            ? require(sft_state == SFT_STATE.MINT, "Mint is closed")
            : require(sft_state == SFT_STATE.OPEN_MARKET, "Market is closed");
    }

    /// @notice Allows the owner of the contract to withdraw funds
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
