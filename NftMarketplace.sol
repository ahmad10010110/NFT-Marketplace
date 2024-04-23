// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract NftMarketplace {
    // Total supply of tokens
    uint private  totalSupply;
    // Price per token
    uint public tokenPrice = 0.0001 ether;

    // Name and symbol of the token
    string public name = "Market Place Token";
    string public symbol = "MPT";

    // Event emitted on token transfer
    event TransferToken(address indexed from, address indexed to, uint value);
    // Event emitted on NFT transfer
    event TransferNFT(address indexed from, address indexed to, uint indexed nftID);

    // Owner of the marketplace contract
    address public marketPlaceOwner;

    // Mapping to track token balances of users
    mapping(address => uint) internal balanceTokenOf;

    // Mapping from NFT ID to owner address
    mapping(uint => address) internal _ownerOf;

    // Mapping owner address to NFT count
    mapping(address => uint) internal balanceOf;

    // Mapping from user to their NFTs
    mapping(address => mapping(uint => NFT)) internal _allNftsOfOwner;

    // Mapping from user to their English auctions
    mapping(address => mapping(uint => englishAuction)) internal englishAuctionOf;

    // Mapping from user to their Dutch auctions
    mapping(address => mapping(uint => dutchAuction)) internal dutchAuctionOf;    

    // Struct for representing NFTs
    struct NFT {
        string title;
        uint nftID;
        address owner;
        string description;
        uint price;
        string nft;
        bool forSell;
        bool forEnglishAuction;
        bool forDutchAuction;
    }

    // Array of all NFTs
    NFT[] internal nfts;

    // Struct for representing English auctions
    struct englishAuction {
        bool open;
        uint englishAuctionID;
        uint nftID;
        address nftOwner;
        uint start;
        uint duration;
        uint startingBid;
        address highestBidder;
        uint highestBid;
        uint buyOutPrice;
    }

    // Array of all English auctions
    englishAuction[] internal englishAuctions;

    // Struct for representing Dutch auctions
    struct dutchAuction {
        bool open;
        uint dutchAuctionID;
        uint nftID;
        address nftOwner;
        uint startTime;
        uint startingPrice;
        uint discountRate;
        uint durationInDays;
    }

    // Array of all Dutch auctions
    dutchAuction[] internal dutchAuctions;

    // Constructor to set the marketplace owner and initialize token balance
    constructor() {
        marketPlaceOwner = msg.sender;
        balanceTokenOf[address(this)] = 0;
    }


    // Function to mint tokens
    function mint(uint amount) internal {
        balanceTokenOf[msg.sender] += amount; // Increase token balance of the caller
        totalSupply += amount; // Increase total supply of tokens
        emit TransferToken(address(0), msg.sender, amount); // Emit TransferToken event
    }

    // Function to buy tokens
    function buyToken() public payable {
        uint receivedEther = msg.value; // Get the amount of Ether received
        uint amount = receivedEther / tokenPrice; // Calculate the amount of tokens to mint
        mint(amount); // Mint tokens for the buyer
    }

    // Function to show token balance of a user
    function showBalanceToken(address user) public view returns(uint) {
        require(msg.sender == user || msg.sender == marketPlaceOwner, "Unauthorized"); // Ensure caller is authorized
        return balanceTokenOf[user]; // Return the token balance of the user
    }

    // Function to transfer tokens from one address to another
    function transferFrom(address sender, address recipient, uint amount) internal returns (bool) {
        require(balanceTokenOf[sender] >= amount, "Insufficient balance"); // Ensure sender has enough balance
        balanceTokenOf[sender] -= amount; // Deduct tokens from sender
        balanceTokenOf[recipient] += amount; // Add tokens to recipient
        emit TransferToken(sender, recipient, amount); // Emit TransferToken event
        return true; // Return success
    }

    // Function to withdraw Ether
    function withdrawal(uint amount) public payable returns(bool) {
        address payable to = payable(msg.sender); // Get recipient address
        require(balanceTokenOf[to] >= amount, "Insufficient balance"); // Ensure account has enough balance
        balanceTokenOf[to] -= amount; // Deduct tokens from sender
        // Send Ether from the contract to the recipient
        (bool sent, ) = to.call{value: amount * tokenPrice}("");
        require(sent, "Failed to send Ether"); // Ensure Ether transfer is successful
        return sent; // Return success
    }

    // Function to start a Dutch auction
    function startDutchAuction(uint nftID, uint startingPrice, uint discountRate, uint durationInDays) public {
        require(msg.sender == _ownerOf[nftID], "Not owner"); // Ensure caller is the owner of the NFT
        require(startingPrice >= discountRate * durationInDays, "Starting price < minimum"); // Validate starting price
        // Create a new Dutch auction
        uint dutchAuctionID = dutchAuctions.length;
        dutchAuction memory auction = dutchAuction(
            true,
            dutchAuctionID, 
            nftID, 
            msg.sender, 
            block.timestamp, 
            startingPrice, 
            discountRate,
            durationInDays
        );
        dutchAuctions.push(auction); // Add the auction to the list
        dutchAuctionOf[msg.sender][dutchAuctionID] = auction; // Map auction to the owner
        // Set NFT status for Dutch auction
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == auction.nftID){
                nfts[i].forDutchAuction = true;
            }
        }
    }

    // Function to get the current price of a Dutch auction
    function getPriceOfDutchAuction(uint dutchAuctionID) view public returns(uint) {
        uint auctionIndex;
        for (uint i = 0; i < dutchAuctions.length; i++) {
            if (dutchAuctions[i].dutchAuctionID == dutchAuctionID) {
                auctionIndex = i;
                break;
            }
        }
        dutchAuction storage auction = dutchAuctions[auctionIndex];
        // Calculate the current price based on time elapsed and discount rate
        uint timeElapsed = block.timestamp - auction.startTime;
        uint daysElapsed = timeElapsed / (24 * 60 * 60);
        uint discount = auction.discountRate * daysElapsed;
        int price = int(auction.startingPrice - discount);
        return price >= 0 ? uint(price) : 0; // Return the current price
    }

    // Function to buy an NFT in a Dutch auction
    function buyInDutchAuction(uint dutchAuctionID, uint bid) public {
        uint auctionIndex;
        for (uint i = 0; i < dutchAuctions.length; i++) {
            if (dutchAuctions[i].dutchAuctionID == dutchAuctionID) {
                auctionIndex = i;
                break;
            }
        }
        dutchAuction storage auction = dutchAuctions[auctionIndex];
        uint expiresAt = block.timestamp + auction.durationInDays;
        require(block.timestamp < expiresAt, "Auction expired"); // Ensure auction is still active
        uint price = getPriceOfDutchAuction(auction.dutchAuctionID);
        require(bid >= price, "Bid < price"); // Ensure bid is at least the current price
        // Transfer funds and update balances
        uint amount = bid - price;
        transferFrom(msg.sender, _ownerOf[auction.nftID], amount);
        balanceOf[_ownerOf[auction.nftID]]--;
        balanceOf[msg.sender]++;
        _ownerOf[auction.nftID] = msg.sender;
        _allNftsOfOwner[msg.sender][auction.nftID] = nfts[auctionIndex];
        nfts[auctionIndex].owner = msg.sender;
        auction.open = false; // Close the auction
        delete _allNftsOfOwner[auction.nftOwner][auction.nftID]; // Remove NFT from previous owner
        nfts[auctionIndex].forDutchAuction = false; // Update NFT status
    }

    // Function to show details of a Dutch auction by ID
    function showDutchAuction(uint dutchAuctionID) public view returns (
        bool open,
        uint auctionID,
        uint nftID,
        address nftOwner,
        uint startTime,
        uint startingPrice,
        uint discountRate,
        uint durationInDays
    ) {
        for (uint i = 0; i < dutchAuctions.length; i++) {
            if (dutchAuctions[i].dutchAuctionID == dutchAuctionID) {
                // Return details of the auction if found
                return (
                    dutchAuctions[i].open, 
                    dutchAuctions[i].dutchAuctionID,
                    dutchAuctions[i].nftID, 
                    dutchAuctions[i].nftOwner, 
                    dutchAuctions[i].startTime,
                    dutchAuctions[i].startingPrice,
                    dutchAuctions[i].discountRate,
                    dutchAuctions[i].durationInDays
                );
            }
        }
        // Handle the case where no matching auction ID is found
        return (false, 0, 0, address(0), 0, 0, 0, 0);
    }

    // Function to show IDs of open Dutch auctions
    function showOpenDutchAuctionsID() public view returns(uint[] memory) {
        uint count = 0;
        for (uint i = 0; i < dutchAuctions.length; i++ ) {
            if (dutchAuctions[i].open) {
                count++;
            }
        }
        uint[] memory openDutchAuctions = new uint[](count);
        uint index = 0;
        for (uint i = 0; i < dutchAuctions.length; i++) {
            if (dutchAuctions[i].open) {
                // Add ID of open auction to the array
                openDutchAuctions[index] = dutchAuctions[i].dutchAuctionID;
                index++;
            }
        }
        return openDutchAuctions; // Return array of open auction IDs
    }

    // Function to start an English auction
    function startEnglishAuction(uint nftID, uint durationInDays, uint startingBid, uint buyOutPrice) public {
        require(msg.sender == _ownerOf[nftID], "Not the owner");
        uint englishAuctionID = englishAuctions.length;
        englishAuction memory auction = englishAuction(
            true,
            englishAuctionID, 
            nftID, 
            msg.sender, 
            block.timestamp, 
            durationInDays * 1 days, 
            startingBid,  
            address(this),
            startingBid,
            buyOutPrice
        );
        // Start locking process
        balanceTokenOf[auction.highestBidder] += auction.highestBid;
        englishAuctions.push(auction);
        englishAuctionOf[msg.sender][englishAuctionID] = auction;
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == auction.nftID){
                nfts[i].forEnglishAuction = true;
            }
        }
    }

    // Function to end an English auction
    function endEnglishAuction(uint englishAuctionID) public {
        uint auctionIndex;
        for (uint i = 0; i < englishAuctions.length; i++) {
            if (englishAuctions[i].englishAuctionID == englishAuctionID) {
                auctionIndex = i;
                break;
            }
        }
        englishAuction storage auction = englishAuctions[auctionIndex];
        uint endTime = auction.start + auction.duration;
        require(block.timestamp >= endTime || auction.buyOutPrice == auction.highestBid);
        // Find NFT index
        uint nftIndex;
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == auction.nftID) {
                nftIndex = i;
                break;
            }
        }
        // Unlocking bidder tokens
        balanceTokenOf[address(this)] -= auction.highestBid;
        balanceTokenOf[auction.highestBidder] += auction.highestBid;
        // Transfering NFT
        transferFrom(msg.sender,_ownerOf[auction.nftID], auction.highestBid);
        balanceOf[_ownerOf[auction.nftID]]--;
        balanceOf[auction.highestBidder]++;
        _ownerOf[auction.nftID] = auction.highestBidder;
        _allNftsOfOwner[auction.highestBidder][auction.nftID] = nfts[nftIndex];
        nfts[nftIndex].owner = msg.sender;
        auction.open = false;
        delete _allNftsOfOwner[auction.nftOwner][auction.nftID];

        nfts[nftIndex].forEnglishAuction = false;
    }

    // Function for a user to participate in an English auction
    function participateInEnglishAuction(uint bid, uint englishAuctionID) public {
        uint auctionIndex;
        for (uint i = 0; i < englishAuctions.length; i++) {
            if (englishAuctions[i].englishAuctionID == englishAuctionID) {
                auctionIndex = i;
                break;
            }
        }
        englishAuction storage auction = englishAuctions[auctionIndex];
        uint endTime = auction.start + (auction.duration * 24 * 60 * 60);
        require(block.timestamp < endTime);
        require(auction.highestBid < bid);
        require(balanceTokenOf[msg.sender] >= bid, "The account balance is insufficient");

        if (bid >= auction.buyOutPrice) {
            endEnglishAuction(auction.englishAuctionID);
        }
        // Locking bidder tokens
        balanceTokenOf[msg.sender] -= bid;
        balanceTokenOf[address(this)] += bid;
        // Unlocking previous highest Bid
        balanceTokenOf[address(this)] -= auction.highestBid;
        balanceTokenOf[auction.highestBidder] += auction.highestBid;
        // Updating highest Bid
        auction.highestBid = bid;
        auction.highestBidder = msg.sender;
    }

    // Function to show details of a specific English auction
    function showEnglishAuction(uint englishAuctionID) public view returns (
        bool open,
        uint nftID,
        address nftOwner,
        uint start,
        uint duration,
        uint highestBid,
        uint buyOutPrice
    ) {
        for (uint i = 0; i < englishAuctions.length; i++) {
            if (englishAuctions[i].englishAuctionID == englishAuctionID){
                return (
                    englishAuctions[i].open, 
                    englishAuctions[i].nftID,
                    englishAuctions[i].nftOwner, 
                    englishAuctions[i].start, 
                    englishAuctions[i].duration,
                    englishAuctions[i].highestBid,
                    englishAuctions[i].buyOutPrice
                );
            }
        }
        // Handle the case where no matching auction ID is found
        return (false, 0, address(0), 0, 0, 0, 0);
    }

    // Function to show IDs of open English auctions
    function showOpenEnglishAuctionsID() public view returns(uint[] memory) {
        uint count = 0;
        for (uint i = 0; i < englishAuctions.length; i++ ) {
            if (englishAuctions[i].open) {
                count++;
            }
        }
        uint[] memory openEnglishAuctions = new uint[](count);
        uint index = 0;
        for (uint i = 0; i < englishAuctions.length; i++) {
            if (englishAuctions[i].open) {
                openEnglishAuctions[index] = englishAuctions[i].englishAuctionID;
                index++;
            }
        }
        return openEnglishAuctions;
    }

    // Function to mint a new NFT
    function _mint(
        string memory  title, 
        string memory  description, 
        string memory  nft, 
        uint priceOfNft
    ) public {
        address to = msg.sender;
        require(to != address(0), "Mint to zero address");
        uint nftID =  nfts.length;
        nfts.push(NFT(title, nftID, msg.sender, description, priceOfNft, nft, false, false, false));   
        _ownerOf[nftID] = to;
        balanceOf[to]++;
        _allNftsOfOwner[to][nftID] = NFT(title, nftID,  msg.sender, description, priceOfNft, nft, false, false, false);
    }

    // Function to set an NFT for sale
    function setToSell(uint tokenId) public {
        require(msg.sender == _ownerOf[tokenId], "Not owner");
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == tokenId){
                nfts[i].forSell = true;
            }
        }
    }

    // Function to convert uint to string
    function uint2str(uint num) internal pure returns (string memory) {
        if (num == 0) {
            return "0";
        }
        uint length = 0;
        uint temp = num;
        // Count the number of digits in the number
        while (temp != 0) {
            length++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(length);
        // Convert each digit to its ASCII equivalent
        while (num != 0) {
            length -= 1;
            buffer[length] = bytes1(uint8(48 + num % 10)); // '0' ASCII value is 48
            num /= 10;
        }
        return string(buffer);
    }

    // Function to convert address to string
    function addressToString(address _address) internal pure returns(string memory) {
        bytes32 value = bytes32(uint256(uint160(_address)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        // Convert each byte of the address to hexadecimal string representation
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0F))];
        }

        return string(str);
    }

    // Function to return NFTs available for sale
    function showForSell() public view returns(string[] memory) {
        uint count = 0;
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].forSell) {
                count++;
            }
        }
        string[] memory toSell = new string[](count);
        count = 0;
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].forSell) {
                // Format the NFT details into a string array
                toSell[count] = string(abi.encodePacked("\n",
                "TokenId:  ", uint2str(nfts[i].nftID), "\n",
                "Title:  ", nfts[i].title, "\n",
                "Price:  ", uint2str(nfts[i].price), "\n",
                "Owner:  ", addressToString(nfts[i].owner), "/n"));
                count++;
            }
        }
        return toSell;
    }

    // Function to buy an NFT
    function buyNFT(uint nftID, uint amount) public {
        uint nftIndex;
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == nftID) {
                nftIndex = i;
                break;
            }
        }
        // Check if the NFT is available for sale and if the price matches
        require(nfts[nftIndex].forSell == true);
        require(nfts[nftIndex].price == amount);
        // Transfer NFT ownership and update balances
        transferFrom(msg.sender, nfts[nftIndex].owner, amount);
        balanceOf[nfts[nftIndex].owner]--;
        balanceOf[msg.sender]++;
        _ownerOf[nftID] = msg.sender;
        _allNftsOfOwner[msg.sender][nftID] = nfts[nftIndex];
        delete _allNftsOfOwner[nfts[nftIndex].owner][nftID];
        nfts[nftIndex].owner = msg.sender;
        nfts[nftIndex].forSell = false;
    }

    // Function to get the balance of NFTs owned by an address
    function nftBalanceOf(address owner) public view returns(uint) {
        return balanceOf[owner];
    }

    // Function to retrieve NFTs available for Dutch auction
    function showForDutchAuction() public view returns(uint[] memory) {
        uint[] memory toDutchAuction = new uint[](nfts.length);
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].forDutchAuction) {
                toDutchAuction[i] = nfts[i].nftID;
            }
        }
        return toDutchAuction;
    }

    // Function to retrieve NFTs owned by a specific address
    function showNftsOwner(address owner) public view returns(uint[] memory) {
        uint[] memory nftList = new uint[](balanceOf[owner]);
        uint index = 0;

        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].owner == owner) {
                nftList[index] = nfts[i].nftID;
                index++;
            }
        }
        return nftList;
    }

    // Function to show details of a specific NFT
    function showNFT(uint tokenId) public view returns (
        string memory title,
        address owner,
        string memory description,
        uint price,
        string memory nft,
        bool forSell,
        bool forEnglishAuction,
        bool forDutchAuction) {
        for (uint i = 0; i < nfts.length; i++) {
            if (nfts[i].nftID == tokenId){
                return (
                    nfts[i].title,
                    nfts[i].owner, 
                    nfts[i].description, 
                    nfts[i].price, 
                    nfts[i].nft,
                    nfts[i].forSell, 
                    nfts[i].forEnglishAuction,
                    nfts[i].forDutchAuction
                );
            }
        }
        // Handle the case where no matching tokenId is found
        return ("", address(0),"", 0, "",false,false,false);
    }
}