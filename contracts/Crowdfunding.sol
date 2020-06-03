pragma solidity ^0.6.0;

import "./ERC223/token/ERC223/IERC223Recipient.sol";
import "./ERC223/token/ERC223/SafeMath.sol";
import "./ICrowdfunding.sol";
import "./ERC223/token/ERC223/Roles.sol";
import "./Project.sol";
import "./FundingToken.sol";


contract Crowdfunding is IERC223Recipient {
    using SafeMath for uint;
    using Roles for Roles.Role;
    mapping(address => bool) private has_open_projects;
    mapping(address => address) public OwnerToProjects;
    mapping(address => Project)public projects;
    Roles.Role private _projectOwners;
    Roles.Role private _users;
    Roles.Role private openProjects;
    uint256 public ProjectPrice;
    Roles.Role private _owner;
    mapping(address => uint256) public accountBalance;
    uint256 public PricingFee;
    address[] public projects_addresses;
    FundingToken public Tokens;
    bool public ready_for_projects = false;
    uint256 public commission;

    modifier onlyOwner(){
        require(_owner.has(msg.sender));
        _;
    }

    modifier sufficientFunds(uint256 _value){
        require(accountBalance[msg.sender] >= _value);
        _;
    }

    modifier isReady(){
        require(ready_for_projects);
        _;
    }

    constructor(address owner)public{
        _owner.add(owner);
    }

    function getReady() external onlyOwner {
        ready_for_projects = true;
    }

    function setCommission(uint256 _commission) external onlyOwner {
        commission = _commission;
    }

    function setTokens(address _tokens) external onlyOwner {
        Tokens = FundingToken(_tokens);
    }

    function changePricingFee(uint256 _pricing) external onlyOwner {
        PricingFee = _pricing;
    }

    function setProjectPrice(uint _price) external onlyOwner {
        require(_price >= 0);
        ProjectPrice = _price;
    }

    function hasAccount(address _who) external view returns (bool) {
        if (_users.has(_who)) {
            return true;
        }
        else if (_projectOwners.has(_who)) {
            return true;
        }
        else {
            return false;
        }
    }

    function addProject() external sufficientFunds(ProjectPrice) isReady {
        require(ready_for_projects);
        require(!has_open_projects[msg.sender]);
        accountBalance[msg.sender] = accountBalance[msg.sender].sub(ProjectPrice);
        Project p = new Project(msg.sender, address(Tokens));
        OwnerToProjects[msg.sender]=address(p);
        projects_addresses.push(address(p));
        projects[address(p)] = p;
        openProjects.add(address(p));
        p.setCommission(commission);
        _projectOwners.add(msg.sender);
        has_open_projects[msg.sender]=true;
    }


    function addUser() external {
        require(ready_for_projects);
        require(!_users.has(msg.sender));
        _users.add(msg.sender);
    }

    function changePricing(address _project_owner) external  isReady {
        require(accountBalance[_project_owner] >= PricingFee);
        require(_projectOwners.has(_project_owner));
        require(_projectOwners.has(tx.origin));
        require(openProjects.has(msg.sender));
        Project p = Project(msg.sender);
        require(p.hasOwner(_project_owner));
        require(accountBalance[_project_owner] >= PricingFee);
        accountBalance[_project_owner] = accountBalance[_project_owner].sub(PricingFee);
    }


    function tokenFallback(address _from, uint _value, bytes calldata _data) override external {
        require(msg.sender == address(Tokens));
        require(this.hasAccount(_from));
        accountBalance[_from] = accountBalance[_from].add(_value);
        emit BalanceRaised(_from, accountBalance[_from]);
    }

    event BalanceRaised(address user, uint256 balance);


}
