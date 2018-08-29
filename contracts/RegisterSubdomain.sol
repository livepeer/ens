pragma solidity ^0.4.24;

import "./Ownable.sol";

interface ENS {
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) public;
    function setResolver(bytes32 node, address resolver) public;
    function setOwner(bytes32 node, address owner) public;
    function setTTL(bytes32 node, uint64 ttl) public;
    function owner(bytes32 node) public view returns (address);
    function resolver(bytes32 node) public view returns (address);
    function ttl(bytes32 node) public view returns (uint64);
}


interface DefaultReverseResolver{
     function setName(bytes32 node, string _name);
}

interface ReverseRegistrar{
    function claim(address owner) public returns (bytes32);
    function node(address addr) constant returns (bytes32);    
}

interface PublicResolver{
    function setAddr(bytes32 node, address addr);
    function setContent(bytes32 node, bytes32 hash);
    function setMultihash(bytes32 node, bytes hash);
    function setName(bytes32 node, string name);
    function setABI(bytes32 node, uint256 contentType, bytes data);
    function setPubkey(bytes32 node, bytes32 x, bytes32 y);
    function setText(bytes32 node, string key, string value);
}


contract RegisterSubdomain is Ownable {
    ENS public ens;
    PublicResolver public publicResolver;
    ReverseRegistrar public reverseRegistrar;
    DefaultReverseResolver public defaultReverseResolver;

    // namehash('addr.reverse')
    bytes32 constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    bytes32 public rootNode;
    string public rootName; 
    address public owner;


    modifier onlyENSNodeOwner(bytes32 node) {
        address currentOwner = ens.owner(node);
        require(currentOwner == address(this),"Not owner of node");
        _;
    }

    /**
     * Constructor.
     * @param _ens The address of the ENS registry.
     * @param _publicResolver The address of the public resolver
     * @param _defaultReverseResolver The address of the default reverse resolver 
     * @param _rootNode The node that this registrar administers.i.e: namehash('transcoder.eth')
     * @param _rootName The name of the root node "trancoder.eth". 
     */
    constructor (address _ens, address _publicResolver,address _defaultReverseResolver, bytes32 _rootNode, string _rootName) public {
        ens = ENS(_ens);
        publicResolver = PublicResolver(_publicResolver);
        reverseRegistrar = ReverseRegistrar(ens.owner(ADDR_REVERSE_NODE));
        defaultReverseResolver = DefaultReverseResolver(_defaultReverseResolver);
        rootNode = _rootNode;
        rootName = _rootName; 
    }

    /**
     * Register subdomain
     * @param name The name in "<name>.trancoder.eth"
     */       
    function registerSubdomain(string name) public {       
        bytes32 subnode = keccak256(name);
        require(ens.owner(keccak256(rootNode, subnode)) == 0,"Subdomain is already registered");
        ens.setSubnodeOwner(rootNode, subnode, address(this));
        bytes32 fullHash = keccak256(rootNode, subnode);
        ens.setResolver(fullHash, address(publicResolver));
        publicResolver.setAddr(fullHash, msg.sender);
        
        //Reverse Registration
        string memory fullName = string(abi.encodePacked(name,".",rootName));
        bytes32 reverseNode = reverseRegistrar.node(msg.sender);
        ens.setResolver(reverseNode,defaultReverseResolver);
        defaultReverseResolver.setName(reverseNode,fullName);       
    }

    function transferDomainOwnership(address to) public onlyOwner{
        ens.setOwner(rootNode,to);
    }

    function transferNodeOwnership(bytes32 node,address owner) public onlyOwner onlyENSNodeOwner(node){
        ens.setOwner(node,owner);
    }

    function reverseRegistrarSetname(bytes32 node,string name) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        DefaultReverseResolver revResolver = DefaultReverseResolver(resolver);
        revResolver.setName(node,name);
    }

    function setAddr(bytes32 node, address addr) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setAddr(node,addr);
    }

    function setContent(bytes32 node, bytes32 hash) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setContent(node,hash);
    }

    function setMultihash(bytes32 node, bytes hash) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setMultihash(node,hash);
    }

    function setName(bytes32 node, string name) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setName(node,name);        
    }

    function setABI(bytes32 node, uint256 contentType, bytes data) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setABI(node,contentType,data);         
    }

    function setPubkey(bytes32 node, bytes32 x, bytes32 y)  public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setPubkey(node,x,y);            
    }

    function setText(bytes32 node, string key, string value) public onlyOwner onlyENSNodeOwner(node){
        address resolver = ens.resolver(node);
        PublicResolver pubResolver = PublicResolver(resolver);
        pubResolver.setText(node,key,value);
    }

}