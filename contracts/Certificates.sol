// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract EasyCerts is ERC721 , ERC721URIStorage ,Ownable , ReentrancyGuard{

    using ECDSA for bytes32;

    using Counters for Counters.Counter;
    Counters.Counter private _certificatesIds;

    // ssigner address
    address public immutable signer;

    constructor(string memory name, string memory symbol, address _signer) ERC721(name, symbol) {
        signer = address( _signer);
    }


    // defining enum 
    enum CertificateStatus { Active, Expired, Revoked }



    // Event
    event CeritificateCreated(address indexed creator, address indexed candidate, uint256 indexed id , uint256 timeofCreation);
    event NFTTransferRequest(address indexed  from , address indexed to , uint256 indexed id);
    event ValidityOfCertificateUpdated(address indexed  from , address indexed to , uint256 indexed id , uint256 time);
    event CeritificatesRevoked(address indexed  from , address indexed to , uint256 indexed id);
    

    // Error
    error NotTeacher();
    error UserCannotTransferCertificates();

    // Mappings
    mapping(address => bool) public isTeacher;
    mapping(bytes32 => bool ) public isHashed;
    mapping(uint256 => Certificate) public idToCertificate;
    mapping(address => uint256[]) public addressToid;

    // Modifier
    function  onlyTeacher(address _address) internal view  returns(bool) {
        if(isTeacher[_address] == true){
            return true;
        }else{
            return false;
        }
    }


    modifier onlySigner(address _address)  {
        require(_address == signer , "Only signer can call this function");
        _;
        
    }


    // Struct
    struct Certificate{
        uint256 id;
        string tokenURI;
        address candidate;
        address  issuer;
        uint256 timeOfIssueance;
        uint256 validTill;
        CertificateStatus status;
    }


    // Main functions


    function verifySignature(
    address to,
    string memory tokenuri,
    uint256 daysTillValid,
    uint256 _id,
    bytes memory signature
) public view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(to, tokenuri, daysTillValid,_id));
    bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);

    return ECDSA.recover(ethSignedMessageHash, signature) == signer;
}


    // Calling this function before a token transfer
    function _beforeTokenTransfer(address from, address to, uint256 tokenId , uint256 batchSize) internal override(ERC721)  {
        (bool isteacher) = onlyTeacher(from);
        if(
            isteacher == false
        ){
            require(from == address(0), "Token not transferable");
        }else{
            super._beforeTokenTransfer(from, to, tokenId,batchSize);
        }
    }


    function mintCertificate(address to , string memory tokenuri , uint256 daysTillValid ,  bytes memory signature) external nonReentrant{
        (bool isteacher) = onlyTeacher(msg.sender);

        // Create a unique hash for each certificate based on some of its unique features
    bytes32 uniqueCertificateHash = keccak256(abi.encodePacked(to, tokenuri, daysTillValid, _certificatesIds.current()));

          // Check if this hash already exists to prevent duplicate certificates
    require(isHashed[uniqueCertificateHash] == false, "Duplicate certificate detected");

        require(
        verifySignature(to, tokenuri, daysTillValid, _certificatesIds.current()  ,signature),
        "Invalid signature"
    );

        if(isteacher == true){
            uint256 tokenId = _certificatesIds.current();
             _safeMint(to, tokenId);
             _setTokenURI(tokenId, tokenuri);
             _certificatesIds.increment();

            idToCertificate[tokenId] = Certificate(
            tokenId,
            tokenuri,
            to,
            msg.sender,
            block.timestamp,
            block.timestamp + daysTillValid * 1 days,
            CertificateStatus.Active
         );
            // Mark this certificate hash as minted
        isHashed[uniqueCertificateHash] = true;
         addressToid[to].push(tokenId);

            emit CeritificateCreated(msg.sender, to, tokenId , block.timestamp);
        }

        else{
            revert NotTeacher();
        }
    }


    // adding  teachers to mapping  
    function addTeacher(address _address) external onlySigner(msg.sender) {
        isTeacher[_address] = true;
    }

    // removing teacher from mapping
    function removeTeacher(address _address)   external onlySigner(msg.sender){
        isTeacher[_address] = false;
    }

    // updating the ceritificate Validity 
    function updateCertificateValidity(uint256 _id, uint256 _days) external nonReentrant  {
        (bool isteacher) = onlyTeacher(msg.sender);
        require(_days > 0 , "Days should be greater than 0");
        require(_id > 0 , "Id should be greater than 0");
        require(idToCertificate[_id].status != CertificateStatus.Revoked, "Certificate is revoked");

        if(
            isteacher == false
        ){
            revert NotTeacher();
        }else{
            idToCertificate[_id].validTill = block.timestamp + _days * 1 days;
            emit ValidityOfCertificateUpdated(msg.sender, idToCertificate[_id].candidate, _id, block.timestamp);

        }
    }


     // revoking the certificate
    function revokeCertificate(uint256 _id) external nonReentrant  {
        (bool isteacher) = onlyTeacher(msg.sender);
       require(idToCertificate[_id].status != CertificateStatus.Revoked, "Certificate is already revoked");

        
        if(
            isteacher == false
        ){
            revert NotTeacher();
        }else{
           idToCertificate[_id].status = CertificateStatus.Revoked; // Set status to Revoked
            emit CeritificatesRevoked(msg.sender, idToCertificate[_id].candidate, _id);
        }
    }


    // =========   View functions


    // get ceritificate status
    function getCertificateStatus(uint256 _id) public view returns(CertificateStatus) {
    return idToCertificate[_id].status;
}

      // getting all the certificates of a candidate
    function getCertificates(address _address) public view returns(uint256[] memory){
        return addressToid[_address];
    }

       // getting the certificate details
    function getCertificateDetails(uint256 _id) public view returns(Certificate memory){
        return idToCertificate[_id];
    }

    // getting the total number of certificates
    function getTotalCertificates() public view returns(uint256){
        return _certificatesIds.current();
    }


    // fetching all the Ceritificates of a Candidate 
    function fetchMYNFTs(address  _address) public view returns(Certificate[] memory){
         uint256 nftcount = _certificatesIds.current();
        uint256 currentIndex = 0;

        Certificate[] memory nfts = new Certificate[](nftcount);

        for(uint256  i = 0 ; i < nftcount ; i++){
            if(idToCertificate[i+1].candidate == _address){
                uint256 currrentId = i + 1 ;

                Certificate storage currentNFT = idToCertificate[currrentId];
                nfts[currentIndex] = currentNFT;
                currentIndex += 1 ;
            }
        }
        return nfts;
    }


    // fetching all Ceritificates  data
    function fetchALLNFTs() public view returns(Certificate[] memory){
        uint256 nftcount = _certificatesIds.current();
        uint256 currentIndex = 0;

        Certificate[] memory nfts = new Certificate[](nftcount);

        for(uint256  i = 0 ; i < nftcount ; i++){
                uint256 currrentId = i + 1 ;
                Certificate storage currentNFT = idToCertificate[currrentId];
                nfts[currentIndex] = currentNFT;
                currentIndex += 1 ;
            
        }
        return nfts;
    }



  

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

}