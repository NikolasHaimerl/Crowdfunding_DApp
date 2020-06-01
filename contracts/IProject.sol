pragma solidity ^0.6.0;


interface  IProject{
    //Adds a timeline to the project. It basically describes how long the project is supposed to be on the crowdfunding platform before shipping starts.
    function addTimeline(uint256 _timeline)external payable;

    //Owners can choose between two different pricing models. One in which there is no limited order number and one where there is. If a limit is set users get their money back
    //as long as order limit has not been reached.
    function choosePricing();


    //An owner of a project can add and remove another owner
    function addProjectOwner(address _CoOwner,address _Owner)external payable;

    function renounceOwner(address _Owner)external payable;


    //An owner should link their project to a pitch video 
    function addVideo(string calldata _video)external payable;


    //A projectowner can change the status of a project. Meaning it can go from concept to in production or shipping.
    function changeStatus()external payable;


    //An owner can set the price for one unit of the product 
    function addMiniumPrice()external payable;




} 
   
   
    