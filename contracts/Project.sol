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
    address payable owner_contact ;
    uint256 public timeline=0;
    string public status="";
    uint8 public pricing=0;
    string public video="";
    bool public ready=false;
    uint256 public unitsSold=0;
    uint256 private limit=0;
    uint256 public unit_price=0;
    address CFunding;
    mapping (address=>uint256) boughtunits;
    address[] private customers;
    mapping (address => uint256) tokensspent;

    uint256 public maxunit_per_purchase=1;
    uint256 public bulk_discount=maxunit_per_purchase;
    uint256 public commission;
    FundingToken public Tokens;
    uint256 starttime;
    uint256 endtime;
    uint256 funded=0;

    constructor(address payable _firstowner ,address _token)public {
        _owners.add(_firstowner);
        owner_contact=_firstowner;
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

    }

    function setCommission(uint _price)external{
        require(msg.sender==CFunding);
        require(_price>=0);
        commission =_price;
    }

    function renounceOwner(address payable  _Owner)external{
        require(_owners.has(msg.sender));
        require(_Owner!=msg.sender);
        _owners.remove(_Owner);
        owner_contact=msg.sender;
    }

    function setdiscount(uint256 _discount)external {
        require(_owners.has(msg.sender));
        require(_discount>=0);
        bulk_discount=_discount;
    }

    function setmaxPurchase(uint256 _max)public onlyOwners {
        maxunit_per_purchase=_max;
    }

    function unitbought(address _buyer,uint256 _units,uint256 _price)private{
        unitsSold=unitsSold.add(_units);
        boughtunits[_buyer]=boughtunits[_buyer].add(_units);
        tokensspent[_buyer]=tokensspent[_buyer].add(_price);
        customers.push(_buyer);
    }

    //An owner should link their project to a pitch video
    function addVideo(string calldata _video)external onlyOwners{
        video=_video;

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

    function hasOwner(address _owner)external returns(bool){
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

    function Funded()external onlyOwners{
        require(ready);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Concept")));
        if(funded>limit){
            status="Funded";
        }
    }
    function inProduction()external onlyOwners{
        require(ready);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("Funded")));
        status="In Production";

    }

    function statusConecpt()external onlyOwners{
        require(ready);
        require(keccak256(abi.encodePacked(status))==keccak256(abi.encodePacked("")));
        status="Concept";

    }

    function abortProject()external onlyOwners{
        if(pricing==0){
            uint prov=funded.div(commission);
            Tokens.transfer(CFunding,prov);
            Tokens.transfer(owner_contact,funded.sub(prov));
        }
        else{
            if(funded<limit){
                for(uint i=0;i<customers.length;i++){
                    Tokens.transfer(customers[i],tokensspent[customers[i]]);
                }
            }
        }
        selfdestruct(owner_contact);
    }




    //An owner can set the price for one unit of the product
    function addUnitPrice()external{
        require(_owners.has(tx.origin));

    }

    function revertPayment()external{
        Crowdfunding cf=Crowdfunding(CFunding);
        require(cf.hasAccount(msg.sender));
        if(unitsSold<limit){
            uint256 spent=tokensspent[msg.sender];
            Tokens.transfer(msg.sender,spent);
            tokensspent[msg.sender]=0;
            unitsSold=unitsSold.sub(boughtunits[msg.sender]);
            boughtunits[msg.sender]=0;
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
        require(_owners.has(tx.origin));
        pricing=0;
    }

    function chooseLimitedPricing()external onlyOwners{
        pricing=1;
        Crowdfunding cf=Crowdfunding(CFunding);
        cf.changePricing(msg.sender);

    }

    function projectReady()external onlyOwners{
        require(bytes(video).length>0);
        require(bytes(status).length>0);
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
