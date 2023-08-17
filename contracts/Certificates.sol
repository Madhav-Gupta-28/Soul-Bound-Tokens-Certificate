// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Certificates is ERC721, ERC721URIStorage, Ownable , ReentrancyGuard  {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;


    // Events 
    event CeritificateCreadted(address indexed _creator, address indexed candidate, uint256 indexed _id);

    // Error 
    error NotTeacher();

    // tecahers array who can issue ceritificates
    address[] public teachers;


    // Modifier
    function   checkIfItisACompany(address _address) internal view returns(bool) {
      bool isCompany = false;

        for(uint256 i = 0 ; i < teachers.length; i++){
            if(teachers[i] == _address){
              isCompany = true;
              break;         
            }
        }

        if(isCompany == true){
          return true;
        }else{
            return false;
        }
       
    }
    
    
    //  Mapping
    mapping(uint256 => Certificate) public idToCertificate;
    mapping(address => uint256[]) public addressToid;

    // Certificate struct
    struct Certificate{
        uint256 id;
        string tokenURI;
        address  candidate;
        address  creator;
        uint256 timeOfIssueance;
        uint256 validTill;
        bool isRevoked;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function _beforeTokenTransfer(address from, address to, uint256 tokenId , uint256 batchSize) internal override(ERC721)  {
        (bool isTeacher) = checkIfItisACompany(msg.sender);
        if(
            isTeacher == false
        ){
            require(from == address(0), "Token not transferable");
        }else{
            super._beforeTokenTransfer(from, to, tokenId,batchSize);
        }
       
        
    }

    function safeMint(address to, string memory tokenURI , uint256 daysTillValid) public onlyOwner nonReentrant {
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _tokenIdCounter.increment();

        idToCertificate[tokenId] = Certificate(
            tokenId,
            tokenURI,
            to,
            msg.sender,
            block.timestamp,
            block.timestamp + daysTillValid * 1 days,
            false
        );
        addressToid[to].push(tokenId);

        emit CeritificateCreadted(msg.sender, to, tokenId);


    }

    // updating teacher list 
    function addTeacher(address _address) public onlyOwner {
        teachers.push(_address);
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
        return _tokenIdCounter.current();
    }

    // getting the total number of teachers
    function getTotalTeachers() public view returns(uint256){
        return teachers.length;
    }

    // updating the ceritificate Validity 
    function updateCertificateValidity(uint256 _id, uint256 _days) public  {
        (bool isTeacher) = checkIfItisACompany(msg.sender);
        if(
            isTeacher == false
        ){
            revert NotTeacher();
        }else{
            idToCertificate[_id].validTill = block.timestamp + _days * 1 days;
        }
    }

    // revoking the certificate
    function revokeCertificate(uint256 _id) public  {
        (bool isTeacher) = checkIfItisACompany(msg.sender);
        if(
            isTeacher == false
        ){
            revert NotTeacher();
        }else{
            idToCertificate[_id].isRevoked = true;
        }
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
