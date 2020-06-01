pragma solidity ^0.4.0;
import "./User.sol";
import "./Project.sol";
import "./ERC223/token/ERC223/IERC223Recipient.sol";
import "./FundingToken.sol";
import "./ICrowdfunding.sol";
import './SafeMath.sol';

contract Crowdfunding is IERC223Recipient,ICrowdfunding{
    using SafeMath for uint;
    using Roles for Roles.Role;
    mapping(address => Project[]) public OwnerToProjects;
    Roles.Role private _projectOwners;
    Roles.Roles private _users;
    uint256 public ProjectPrice;
    Roles.Role private _owner;
    mapping (address=>uint256) accountBalance;
    Project[] public projects;
    FundingToken Tokens;

    modifier onlyOwner(){
        require (_owner.has(msg.sender));
        _;
    }

    modifier sufficientFunds(uint256 _value){
        require (accountBalance[msg.sender]>=_value);
        _;
    }

    constructor(address owner){
        _owner.add(owner);
    }

    function addProjectPrice(uint256 _price)external onlyOwner{
        addProjectPrice=_price;
    }

    function setTokens(address _tokens)external onlyOwner{
        Tokens=FundingToken(_tokens);
    }

    function setProjectPrice(uint _price)external onlyOwner{
        require(_price>=0);
        ProjectPrice=_price;
    }

    function addProject()external sufficientFunds{
        accountBalance[msg.sender]=accountBalance[msg.sender].sub(ProjectPrice);
        Project p=new Project(msg.sender);
        OwnerToProjects[msg.sender]=OwnerToProjects[msg.sender].push(p);
        projects.push(p);
    }


    function addUser()external {
        require(!users.has(msg.sender));
        users.add(msg.sender);
    }

    function tokenFallback(address _from, uint _value, bytes calldata _data) override external{
        require(msg.sender==address(Tokens));
        require(_projectOwners.has(_from) || _users.has(_from));
        accountBalance[_from]=accountBalance[_from].add(_value);
        emit BalanceRaised(_from,accountBalance[_from]);
    }

    event BalanceRaised(address user,uint256 balance);









}
