const ENS = artifacts.require('ENSRegistry.sol');
const SubdomainRegistrar = artifacts.require('SubdomainRegistrar.sol');
const PublicResolver = artifacts.require('PublicResolver.sol');
const FIFSRegistrar = artifacts.require('FIFSRegistrar.sol');
const utils = require('./helpers/Utils.js');
const namehash = require('eth-ens-namehash');

contract('Subdomain Registrar', function (accounts) {

    let registrar, ens, resolver, subdomainRegistrar;

    beforeEach(async () => {
        node = namehash('eth');
        ens = await ENS.new();       
        resolver = await PublicResolver.new(ens.address);  
        registrar = await FIFSRegistrar.new(ens.address, 0);                

        await ens.setOwner(0, registrar.address, { from: accounts[0] });

        //Initialize data
        await registrar.register(web3.sha3('eth'), accounts[0], { from: accounts[0] });

        //Register domain transcoder.eth
        await ens.setSubnodeOwner(namehash('eth'), web3.sha3('transcoder'), accounts[1], { from: accounts[0] })
        assert.equal(await ens.owner(namehash('transcoder.eth')), accounts[1]);

        //Setup Register subdomain contract
        subdomainRegistrar = await SubdomainRegistrar.new(ens.address, resolver.address, namehash('transcoder.eth'), 'transcoder.eth');

        //Transfer ownership of transcoder.eth to our new contract instance
        await ens.setOwner(namehash('transcoder.eth'), subdomainRegistrar.address, { from: accounts[1] });
        assert.equal(await ens.owner(namehash('transcoder.eth')), subdomainRegistrar.address);
    });    

    it('register and transfer subdomain', async () => {
        //Transaction 1 : Create a subdomain for the account
        await subdomainRegistrar.registerSubdomain('testing', {from : accounts[2]});

        //Test we setup resolvers correctly
        assert.equal(await ens.resolver(namehash('testing.transcoder.eth')),resolver.address);

        //Test resolution of domain returns correct address
        resolvedAddr =await resolver.addr(namehash('testing.transcoder.eth'));
        assert.equal(resolvedAddr,accounts[2]);

        //Transfer the domain to another address
        assert.equal(await ens.owner(namehash('testing.transcoder.eth')), accounts[2]);
        await subdomainRegistrar.transferNodeOwnership(web3.sha3('testing'),accounts[3]);
        assert.equal(await ens.owner(namehash('testing.transcoder.eth')), accounts[3]);
    });

    it('transfer ownership of subdomain to different address', async () => {
        assert.equal(await ens.owner(namehash('transcoder.eth')), subdomainRegistrar.address);
        await subdomainRegistrar.transferDomainOwnership(accounts[3],{from : accounts[0]});
        assert.equal(await ens.owner(namehash('transcoder.eth')), accounts[3]);
    });

    it('transfer ownership of subdomain to different address', async () => {
        await subdomainRegistrar.registerSubdomain('testing2', { from: accounts[2] });
        await subdomainRegistrar.registerSubdomain('testing3', { from: accounts[3] });

        //Create a new subdomain Registrar & transfer ownership to it
        newSubdomainRegistrar = await SubdomainRegistrar.new(ens.address, resolver.address, namehash('transcoder.eth'), 'transcoder.eth');
        await subdomainRegistrar.transferDomainOwnership(newSubdomainRegistrar.address, { from: accounts[0] });
        assert.equal(await ens.owner(namehash('transcoder.eth')), newSubdomainRegistrar.address);       

        //This subodomain registrar should be able to re-assign ownerships of the above two subdomains
        await newSubdomainRegistrar.transferNodeOwnership(web3.sha3('testing1'), accounts[4]);
        await newSubdomainRegistrar.transferNodeOwnership(web3.sha3('testing2'), accounts[5]);

        assert.equal(await ens.owner(namehash('testing1.transcoder.eth')), accounts[4]);
        assert.equal(await ens.owner(namehash('testing2.transcoder.eth')), accounts[5]);
    });

    it('should fail to create duplicate subdomain', async () => {       
        await subdomainRegistrar.registerSubdomain('testing1', { from: accounts[1] });
        try {
            await subdomainRegistrar.registerSubdomain('testing1', { from: accounts[2] });
        } catch (error) {
            return utils.ensureException(error);
        }
        assert.fail('Duplicate subdomain was registered!');
    });
});