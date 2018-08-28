const ENS = artifacts.require('ENSRegistry.sol');
const RegisterSubdomain = artifacts.require('RegisterSubdomain.sol');
const PublicResolver = artifacts.require('PublicResolver.sol');
const FIFSRegistrar = artifacts.require('FIFSRegistrar.sol');
const DefaultReverseResolver = artifacts.require('DefaultReverseResolver.sol');
const ReverseRegistrar = artifacts.require('ReverseRegistrar.sol');

const utils = require('./helpers/Utils.js');
const namehash = require('eth-ens-namehash');

contract('RegisterSubdomain', function (accounts) {

    let node;
    let registrar, ens;

    beforeEach(async () => {
        node = namehash('eth');
        ens = await ENS.new();       
        resolver = await PublicResolver.new(ens.address);  
        registrar = await FIFSRegistrar.new(ens.address, 0);               
        defaultRevResolver = await DefaultReverseResolver.new(ens.address);
        reverseRegistrar = await ReverseRegistrar.new(ens.address, defaultRevResolver.address);
        await ens.setSubnodeOwner(0, web3.sha3('reverse'), accounts[0], { from: accounts[0] });
        await ens.setSubnodeOwner(namehash('reverse'), web3.sha3('addr'), reverseRegistrar.address, { from: accounts[0] });       
        await ens.setOwner(0, registrar.address, { from: accounts[0] });
    });

    it('Register subdomain', async () => {
        //Initialize data
        await registrar.register(web3.sha3('eth'), accounts[0], {from: accounts[0]});

        //Register domain transcoder.eth
        await ens.setSubnodeOwner(namehash('eth'),web3.sha3('transcoder'),accounts[1], {from : accounts[0]})
        assert.equal(await ens.owner(namehash('transcoder.eth')),accounts[1]);    

        //Setup Register subdomain contract
        registerSubdomain = await RegisterSubdomain.new(ens.address,resolver.address,defaultRevResolver.address,namehash('transcoder.eth'),'transcoder.eth');

        //Transfer ownership of transcoder.eth to our new contract instance
        await ens.setOwner(namehash('transcoder.eth'),registerSubdomain.address, {from :accounts[1]});
        assert.equal(await ens.owner(namehash('transcoder.eth')), registerSubdomain.address);

        //Following transctions will be called from the livepeer server
        //Transaction 1: Assign reverse address ownership to the register subdomain contract
        await reverseRegistrar.claim(registerSubdomain.address, {from: accounts[2]});

        //Transaction 2 : Create a subdomain/reverse mapping for the account
        await registerSubdomain.registerSubdomain('testing', {from : accounts[2]});

        //Test we setup resolvers correctly
        assert.equal(await ens.resolver(namehash('testing.transcoder.eth')),resolver.address);
        assert.equal(await ens.resolver(namehash(accounts[2].slice(2).toLowerCase() + ".addr.reverse")), defaultRevResolver.address);

        //Test reverse resolution returns right name
        reverseResolvedName = await defaultRevResolver.name(namehash(accounts[2].slice(2).toLowerCase() + ".addr.reverse"));
        assert.equal(reverseResolvedName,'testing.transcoder.eth');

        //Test resolution of domain returns correct address
        resolvedAddr =await resolver.addr(namehash('testing.transcoder.eth'));
        assert.equal(resolvedAddr,accounts[2]);

    });
});
