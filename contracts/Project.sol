pragma solidity ^0.4.0;

import "./ERC223/token/ERC223/Roles.sol";

contract Projects {
    using Roles for Roles.Role;
    //Adds a timeline to the project. It basically describes how long the project is supposed to be on the crowdfunding platform before shipping starts.
    Roles.Role private _owners;
    uint256 public timeline;
    string public status="";
    string public pricing="";

    constructor(address _firstowner)public {
        _owners.add(_firstowner);
    }

    //An owner of a project can add and remove another owner
    function addProjectOwner(address _CoOwner)external {
        require(_owners.has(msg.sender));
        _owners.add(_CoOwner);

    }

    function renounceOwner(address _Owner)external payable;


    //An owner should link their project to a pitch video
    function addVideo(string calldata _video)external payable;


    //A projectowner can change the status of a project. Meaning it can go from concept to in production or shipping.
    function changeStatus()external payable;


    //An owner can set the price for one unit of the product
    function addMiniumPrice()external{

    }


    //Owners can choose between two different pricing models. One in which there is no limited order number and one where there is. If a limit is set users get their money back
    //as long as order limit has not been reached.
    function chooseLimitlessPricing(address _Project)external {
    require()
    }

    function addTimeline(uint256 _timeline)external {
        timeline=_timeline;
    }

}
