const truffleAssert = require('truffle-assertions');

const FundingToken = artifacts.require("FundingToken");
const CrowdFunding = artifacts.require("Crowdfunding");
const Project = artifacts.require("Project");
const web3 = CrowdFunding.web3;
var Web3 = require('web3');

contract("Crowdfunding test", async accounts => {
    let fundingtoken;
    let CFundingPF;
    let master=accounts[0];
    let user1=accounts[1];
    let user2=accounts[2];
    let owner1=accounts[3];
    let owner2=accounts[4];
    let comaster=accounts[5];
    let auctionprice=1;
    let new_toke_price=10;
    let commission=10;
    let projectPrice=1;
    let PricingFee=1;

    async function init() {
        fundingtoken=await FundingToken.new({from:accounts[0]});
        CFundingPF=await CrowdFunding.new(accounts[0]);
        await fundingtoken.mint(fundingtoken.address,10000,{from:master});
        await fundingtoken.mint(owner1,1000,{from:master});
        await fundingtoken.mint(owner2,1000,{from:master});
        await fundingtoken.mint(user1,100,{from:master});
        await fundingtoken.mint(user2,100,{from:master});
        await fundingtoken.setcostofAuction(auctionprice,{from:master});
        await fundingtoken.startAuction(new_toke_price,{from:master});
    }
    async function getPlatformReady() {
        await CFundingPF.setCommission(commission,{from:master});
        await CFundingPF.setTokens(fundingtoken.address,{from:master});
        await CFundingPF.setProjectPrice(projectPrice,{from:master});
        await CFundingPF.changePricingFee(PricingFee,{from:master});
        await CFundingPF.getReady({from:master});
    }

    async function addProjects(owner){
        await CFundingPF.addProject({from:owner});
    }

    async function chargeAccount(user,amount){
        await fundingtoken.transfer(CFundingPF.address,amount,{from:user});
    }

    it("Platform Owner can set: commission , pricingFee,projectPrice,TokenStandard | get Project ready", async () => {
        await init();
        assert.equal(await CFundingPF.ready_for_projects(),false);
        await getPlatformReady();
        assert.equal(await CFundingPF.ready_for_projects(),true);
    });
    it("Only Platform Owner can set: commission , pricingFee,projectPrice,TokenStandard | get Project ready", async () => {
        await truffleAssert.reverts(CFundingPF.setCommission(commission,{from:user1}));
        await truffleAssert.reverts(CFundingPF.setTokens(fundingtoken.address,{from:user1}));
        await truffleAssert.reverts(CFundingPF.setProjectPrice(projectPrice,{from:user1}));
        await truffleAssert.reverts(CFundingPF.changePricingFee(PricingFee,{from:user1}));
        await truffleAssert.reverts(CFundingPF.getReady({from:user1}));
    });

    it("Users can add themselfes once the platform is ready", async () => {
        await init();
        await truffleAssert.reverts(CFundingPF.addUser({from:user1}));
        assert.equal(await CFundingPF.hasAccount(user1),false);
        await getPlatformReady();
        await CFundingPF.addUser({from:user1});
        let p=await CFundingPF.hasAccount(user1,{from:user1});
        assert.equal(p,true);
    });

    it("Users can't add themselfes twice", async () => {
        await init();
        await getPlatformReady();
        await CFundingPF.addUser({from:user1});
        assert.equal(await CFundingPF.hasAccount(user1,{from:user1}),true);
        await truffleAssert.reverts(CFundingPF.addUser({from:user1}));
    });

    it("Users of the platform can add tokens to their account", async () => {
        await init();
        await truffleAssert.reverts(chargeAccount(user1,10));
        await getPlatformReady();
        await CFundingPF.addUser({from:user1});
        await chargeAccount(user1,20);
        await truffleAssert.reverts(chargeAccount(user1,2000));
        await truffleAssert.reverts(chargeAccount(comaster,20));
        assert.equal((await CFundingPF.accountBalance.call(user1)).toNumber(),20);

    });


    it("Projects can be added by anyone if sufficient  funds for the ProjectPrice are available and the platform is ready. Only one project per user to avoid overcrowding", async () => {
        await init();
        await truffleAssert.reverts(addProjects(owner1));
        await getPlatformReady();
        await truffleAssert.reverts(addProjects(comaster));
        await CFundingPF.addUser({from:owner1});
        await chargeAccount(owner1,100);
        await addProjects(owner1);
        await truffleAssert.reverts(addProjects(owner1));
        assert.equal(await CFundingPF.hasAccount(owner1),true);
        let projects=await CFundingPF.OwnerToProjects.call(owner1);
        let project1=await CFundingPF.projects.call(projects);
        let project2=await CFundingPF.projects.call((await CFundingPF.projects_addresses.call(0)));
        assert.equal(project1,project2);

    });

    it("Project owners can change the pricing of their projects if the corresponding fee is payed",async () =>{
        await init();
        await getPlatformReady();
        await CFundingPF.addUser({from:owner1});
        await chargeAccount(owner1,100);
        await addProjects(owner1);
        let projects_address=await CFundingPF.OwnerToProjects.call(owner1);
        let project = await Project.at(projects_address);
        assert.equal(await project.pricing(),0);
        await project.chooseLimitedPricing({from:owner1});
    });













});