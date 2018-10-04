pragma solidity ^0.4.18;

import "./Ownable.sol";

interface IENS {
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) public;
    function setResolver(bytes32 node, address resolver) public;
    function setOwner(bytes32 node, address owner) public;
    function setTTL(bytes32 node, uint64 ttl) public;
    function owner(bytes32 node) public view returns (address);
    function resolver(bytes32 node) public view returns (address);
    function ttl(bytes32 node) public view returns (uint64);
}

interface IPublicResolver{
    function setAddr(bytes32 node, address addr);
    function setContent(bytes32 node, bytes32 hash);
    function setMultihash(bytes32 node, bytes hash);
    function setName(bytes32 node, string name);
    function setABI(bytes32 node, uint256 contentType, bytes data);
    function setPubkey(bytes32 node, bytes32 x, bytes32 y);
    function setText(bytes32 node, string key, string value);
}


contract SubdomainRegistrar is Ownable {
    bytes32 public rootNode;
    string public rootName; 
    address public owner;
    IENS public ens;
    IPublicResolver public publicResolver;

    /**
     * Constructor.
     * @param _ens The address of the ENS registry.
     * @param _publicResolver The address of the public resolver
     * @param _rootNode The node that this registrar administers.i.e: namehash('transcoder.eth')
     * @param _rootName The name of the root node "trancoder.eth". 
     */
    constructor(address _ens, address _publicResolver, bytes32 _rootNode, string _rootName) public {
        ens = IENS(_ens);
        publicResolver = IPublicResolver(_publicResolver);
        rootNode = _rootNode;
        rootName = _rootName; 
    }

    /**
     * Register subdomain
     * @param _name The name in "<name>.trancoder.eth"
     */       
    function registerSubdomain(string _name) public {       
        bytes32 subnode = keccak256(abi.encodePacked(_name));
        require(ens.owner(keccak256(abi.encodePacked(rootNode, subnode))) == address(0),"Subdomain is already registered");
        ens.setSubnodeOwner(rootNode, subnode, address(this));
        bytes32 fullHash = keccak256(abi.encodePacked(rootNode, subnode));
        ens.setResolver(fullHash, address(publicResolver));
        publicResolver.setAddr(fullHash, msg.sender);
        ens.setSubnodeOwner(rootNode, subnode, msg.sender);
    }

    /**
     * Transfer domain ownership i.e "transcoder.eth"
     * @param _to The address to which the domain ownership is transferred to.
     */  
    function transferDomainOwnership(address _to) public onlyOwner{
        ens.setOwner(rootNode,_to);
    }
    
    /**
     * Transfer node ownership i.e "hello.transcoder.eth"
     * @param _subnode namehash of the subdomain to be transferred.
     * @param _newOwner The address to which sub domain ownership is transferred to.
     */
    function transferNodeOwnership(bytes32 _subnode,address _newOwner) public onlyOwner {
        ens.setSubnodeOwner(rootNode,_subnode,_newOwner);
    }
}