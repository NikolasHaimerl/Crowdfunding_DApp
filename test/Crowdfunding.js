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

    async function setupProject(owner){
        await init();
        await getPlatformReady();
        await CFundingPF.addUser({from:owner});
        await chargeAccount(owner,100);
        await addProjects(owner);
        let projects_address=await CFundingPF.OwnerToProjects.call(owner1);
        let project = await Project.at(projects_address);
        return project;

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


    it("Only owner can add another owner",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        assert.equal(await p.hasOwner(owner2,{from:owner1}),false);
        await truffleAssert.reverts(p.addProjectOwner(owner2,{from:user1}));
        await p.addProjectOwner(owner2,{from:owner1});
        assert.equal(await p.hasOwner(owner2,{from:owner1}),true);
    });

    it("Owner(only) can add a pitch video| maximum units per purchase| bulk discount | unit price | limit | timeline",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        assert.equal("https://www.youtube.com/watch?v=lBFmdkEZiMQ",await p.video());
        await p.setdiscount(2,{from:owner1});
        assert.equal(2,(await p.bulk_discount()).toNumber());
        await p.setmaxPurchase(10,{from:owner1});
        assert.equal(10,(await p.maxunit_per_purchase()).toNumber());
        await p.addUnitPrice(10,{from:owner1});
        assert.equal(10,(await p.unit_price()).toNumber());
        await p.addTimeline(50,{from:owner1});
        assert.equal(50,(await p.timeline()).toNumber());


    });

    it("Project has to have all features before users can start funding (pitch video,max units,discount,unit price,limit,timeline",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await CFundingPF.addUser({from:user1});
        await chargeAccount(user1,10);
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        await p.setdiscount(2,{from:owner1});
        await truffleAssert.reverts(fundingtoken.transfer(p.address,11,{from:user1}));
        await p.setmaxPurchase(10,{from:owner1});
        await truffleAssert.reverts(fundingtoken.transfer(p.address,11,{from:user1}));
        await p.addUnitPrice(10,{from:owner1});
        await truffleAssert.reverts(fundingtoken.transfer(p.address,11,{from:user1}));
        await p.addTimeline(50,{from:owner1});
        await truffleAssert.reverts(fundingtoken.transfer(p.address,11,{from:user1}));
        await p.statusConcept({from:owner1});
        await p.projectReady({from:owner1});
        fundingtoken.transfer(p.address,11,{from:user1});
        assert.equal((await p.boughtunits.call(user1)).toNumber(),1);
        assert.equal((await p.tokensspent.call(user1)).toNumber(),11);
        assert.equal((await p.funded()).toNumber(),11);

    });

    it("Users get a bulk discount if they buy more than 2 products",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await CFundingPF.addUser({from:user1});
        await chargeAccount(user1,10);
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        await p.setdiscount(2,{from:owner1});
        await p.setmaxPurchase(10,{from:owner1});
        await p.addUnitPrice(10,{from:owner1});
        await p.addTimeline(50,{from:owner1});
        await p.statusConcept({from:owner1});
        await p.projectReady({from:owner1});
        fundingtoken.transfer(p.address,30,{from:user1});
        assert.equal((await p.boughtunits.call(user1)).toNumber(),5);
        assert.equal((await p.tokensspent.call(user1)).toNumber(),30);
        assert.equal((await p.funded()).toNumber(),30);
    });

    it("Users can revert their payments if pricing with limit is choosen and the current funding is below the limit",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await CFundingPF.addUser({from:user1});
        await chargeAccount(user1,10);
        let f1=(await fundingtoken._balances.call(user1)).toNumber();
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        await p.setdiscount(2,{from:owner1});
        await p.setmaxPurchase(10,{from:owner1});
        await p.addUnitPrice(10,{from:owner1});
        await p.addTimeline(50,{from:owner1});
        await p.statusConcept({from:owner1});
        await p.projectReady({from:owner1});
        await p.setFundingLimit(200,{from:owner1});
        await p.chooseLimitedPricing({from:owner1});
        fundingtoken.transfer(p.address,30,{from:user1});
        assert.equal((await p.boughtunits.call(user1)).toNumber(),5);
        assert.equal((await p.tokensspent.call(user1)).toNumber(),30);
        assert.equal((await p.funded()).toNumber(),30);
        await p.revertPayment({from:user1});
        assert.equal((await p.boughtunits.call(user1)).toNumber(),0);
        assert.equal((await p.tokensspent.call(user1)).toNumber(),0);
        assert.equal((await p.funded()).toNumber(),0);
        assert.equal((await fundingtoken._balances.call(user1)).toNumber(),f1);
    });

    it("Project owners can abort their project. If the limited pricing was chosen users get their money back if the funding limit had not been reached. Otherwise the project owner gets" +
        "all the payments so far minus a commision to the platform owner",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await CFundingPF.addUser({from:user1});
        let f1=(await fundingtoken._balances.call(owner1)).toNumber();
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        await p.setdiscount(2,{from:owner1});
        await p.setmaxPurchase(10,{from:owner1});
        await p.addUnitPrice(10,{from:owner1});
        await p.addTimeline(50,{from:owner1});
        await p.statusConcept({from:owner1});
        await p.projectReady({from:owner1});
        await p.setFundingLimit(200,{from:owner1});
        fundingtoken.transfer(p.address,30,{from:user1});
        await p.abortProject({from:owner1});
        let f2=(await fundingtoken._balances.call(owner1)).toNumber();
        assert.equal(f1+30-3,f2);

    });

    it("Users can get back their tokens if a limited pricing was choosen and the project has not yet been funded (funded>=limit). Once every user has reclaimed their tokens the project will self destruct",async () =>{
        await init();
        await getPlatformReady();
        let p=await setupProject(owner1);
        await CFundingPF.addUser({from:user1});
        await CFundingPF.addUser({from:user2});
        let f1=(await fundingtoken._balances.call(owner1)).toNumber();
        await p.addVideo("https://www.youtube.com/watch?v=lBFmdkEZiMQ",{from:owner1});
        await p.setdiscount(2,{from:owner1});
        await p.setmaxPurchase(10,{from:owner1});
        await p.addUnitPrice(10,{from:owner1});
        await p.addTimeline(50,{from:owner1});
        await p.statusConcept({from:owner1});
        await p.projectReady({from:owner1});
        await p.setFundingLimit(200,{from:owner1});
        await p.chooseLimitedPricing({from:owner1});
        fundingtoken.transfer(p.address,30,{from:user1});
        fundingtoken.transfer(p.address,30,{from:user2});
        await p.abortProject({from:owner1});
        let f3=(await fundingtoken._balances.call(owner1)).toNumber();
        assert.equal(f1,f3);
        await p.requestRefundAfterAbort({from:user1});
        assert.equal(await CFundingPF.has_open_projects.call(owner1),true);
        await p.requestRefundAfterAbort({from:user2});
        assert.equal(await CFundingPF.has_open_projects.call(owner1),false);

    });

});