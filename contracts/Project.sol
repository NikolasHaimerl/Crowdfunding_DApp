pragma solidity ^0.6.0;
import "./ERC223/token/ERC223/SafeMath.sol";
import "./ERC223/token/ERC223/Roles.sol";
import "./ERC223/token/ERC223/IERC223Recipient.sol";
import "./FundingToken.sol";
import "./Crowdfunding.sol";

contract Project is IERC223Recipient{
    using Roles for Roles.Role;
    using SafeMath for uint;

    //Adds a timeline to the project. It basically describes how long the project is supposed to be on the crowdfunding platform before shipping starts.
    Roles.Role private _owners;
    Roles.Role private customer;
    uint256 private owner_count=0;
    address payable public owner_contact ;
    uint256 public timeline=0;
    string public status="";
    uint8 public pricing=0;
    string public video="";
    bool public ready=false;
    uint256 public unitsSold=0;
    uint256 public limit=0;
    uint256 public unit_price=0;
    address private CFunding;
    mapping (address=>uint256) public boughtunits;
    uint256 public customers;
    mapping (address => uint256) public  tokensspent;
    uint256 public maxunit_per_purchase=1;
    uint256 public bulk_discount=maxunit_per_purchase;
    uint256 public commission;
    FundingToken public Tokens;
    uint256 public starttime;
    uint256 public endtime;
    uint256 public funded=0;
    bool public refund_possible=false;

    constructor(address payable _firstowner ,address _token)public {
        _owners.add(_firstowner);
        owner_contact=_firstowner;
        owner_count=owner_count.add(1);
        CFunding=msg.sender;
        Tokens=FundingToken(_token);
    }

    modifier onlyOwners(){
        require(_owners.has(msg.sender));
        _;
    }

    //An owner of a project can add and remove another owner
    function addProjectOwner(address payable _CoOwner)external {
        require(_owners.has(msg.sender));
        _owners.add(_CoOwner);
        owner_count=owner_count.add(1);


    }

    function setCommission(uint _price)external{
        require(msg.sender==CFunding);
        require(_price>=0);
        commission =_price;
    }

    function renounceOwner(address payable  _Owner)external{
        require(_owners.has(msg.sender));
        require(_Owner!=owner_contact);
        require(_Owner!=msg.sender);
        _owners.remove(_Owner);


    }

    function setdiscount(uint256 _discount)external {
        require(_owners.has(msg.sender));
        require(_discount>=0);
        bulk_discount=_discount;
    }

    function setmaxPurchase(uint256 _max)public onlyOwners {
        maxunit_per_purchase=_max;
    }

    function unitbought(address _buyer,uint256 _price,uint256 _units)private{
        unitsSold=unitsSold.add(_units);
        if(unitsSold>=limit){
            status="Funded";
            refund_possible=false;
        }
        boughtunits[_buyer]=boughtunits[_buyer].add(_units);
        tokensspent[_buyer]=tokensspent[_buyer].add(_price);
        if(!customer.has(_buyer)){
            customer.add(_buyer);
            customers=customers.add(1);
        }
    }

    //An owner should link their project to a pitch video
    function addVideo(string calldata _video)external onlyOwners{
        video=_video;

    }

    function requestRefundAfterAbort()external{
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Aborted")));
       require(customer.has(msg.sender));
        require(refund_possible);
         uint stake=tokensspent[msg.sender];
        Tokens.transfer(msg.sender,stake);
         tokensspent[msg.sender]=0;
         boughtunits[msg.sender]=0;
         funded=funded.sub(stake);
         if(customers==1){
             Crowdfunding cf=Crowdfunding(CFunding);
             cf.projectwasDeleted(owner_contact);
             selfdestruct(owner_contact);
         }
        else{
             customers=customers.sub(1);
         }
    }

    function getOwnerContact()external returns(address){
        return owner_contact;
    }

    //A projectowner can change the status of a project. Meaning it can go from concept to in production or shipping.
    function readyforShipping()external{
        require(_owners.has(msg.sender));
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("In Production")));
        status="Ready for shipping";

    }

    function hasOwner(address _owner)external view returns(bool){
        return _owners.has(_owner);
    }

    function shipped()external onlyOwners{
        require(ready);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Ready for shipped")));
        status="Shipped";

    }

    function ProjectFinished()external{
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Shipped")));
        require(msg.sender==CFunding);
        uint comm = funded.div(commission);
        Tokens.transfer(CFunding, comm);
        Tokens.transfer(owner_contact,funded.sub(comm));

    }

    function inProduction()external onlyOwners{
        require(ready);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Funded")));
        status="In Production";

    }

    function statusConcept()external onlyOwners{
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("")));
        status="Concept";

    }

    function abortProject()external onlyOwners {
        require(ready);
        status="Aborted";
        if(pricing==0){
            uint prov=funded.div(commission);
            Tokens.transfer(CFunding,prov);
            Tokens.transfer(owner_contact,funded.sub(prov));
            refund_possible=false;

        }
      else if(funded<limit){
                refund_possible=true;
            }
            else{
                refund_possible=false;
            }


    }




    //An owner can set the price for one unit of the product
    function addUnitPrice(uint256 _price)external onlyOwners{
        unit_price=_price;


    }

    function revertPayment()external{
        Crowdfunding cf=Crowdfunding(CFunding);
        require(cf.hasAccount(msg.sender));
        require(pricing==1);
        if(unitsSold<limit){
            uint256 spent=tokensspent[msg.sender];
            Tokens.transfer(msg.sender,spent);
            tokensspent[msg.sender]=0;
            unitsSold=unitsSold.sub(boughtunits[msg.sender]);
            boughtunits[msg.sender]=0;
            funded=funded.sub(spent);
        }
        else{
            revert();
        }
    }

    function setFundingLimit(uint256 _limit)external onlyOwners{
        limit=_limit;
    }


    //Owners can choose between two different pricing models. One in which there is no limited order number and one where there is. If a limit is set users get their money back
    //as long as order limit has not been reached.
    function chooseLimitlessPricing()external {
        require(_owners.has(msg.sender));
        pricing=0;
    }

    function chooseLimitedPricing()external onlyOwners{
        pricing=1;
        Crowdfunding cf=Crowdfunding(CFunding);
        refund_possible=true;
        cf.changePricing(msg.sender);

    }

    function projectReady()external onlyOwners{
        require(bytes(video).length>0);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Concept")));
        require(timeline>0);
        require(unit_price>0);
        ready=true;
        starttime=block.timestamp;
        endtime=starttime+(timeline.mul(60).mul(24).mul(24));
        status="Ready for purchase";
    }

    function addTimeline(uint256 _timeline)external onlyOwners{
        timeline=_timeline;
    }


    function tokenFallback(address _from, uint _value, bytes calldata _data) override external{
        require(msg.sender==address(Tokens));
        require(ready);
        require(keccak256(abi.encodePacked(status))!=keccak256(abi.encodePacked("Aborted")));
        Crowdfunding cf=Crowdfunding(CFunding);
        uint256 _units=_value.div(unit_price);
        require(_units>0&&_units<=maxunit_per_purchase);
        require(cf.hasAccount(_from));
        if(keccak256(_data)!=keccak256(bytes("fund"))){
            if(_units>2){
                unitbought(_from,_value,(_units+bulk_discount));
                emit UnitsBought(_from,_units+bulk_discount);
            }
            else{
                unitbought(_from,_value,_units);
                emit UnitsBought(_from,_units);

            }

        }
        funded=funded.add(_value);

    }


    event UnitsBought(address _buyer,uint256 _units);

}
