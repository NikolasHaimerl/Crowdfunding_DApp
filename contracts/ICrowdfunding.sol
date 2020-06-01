pragma solidity ^0.6.0;


interface  ICrowdfunding {


    //Projects can be added by owners of a project. The only content a owner is able to transmit
    //in order to make his case is a video link to a Youtube Video which describes the Product and contains a pitch of the product
    function addProject(address _projectOwner,string calldata _videoPitch) external payable;
    //An event is fired with the project owner and their pitch whenever a new project is added
    event newProjectadded(string _ProjectName,address _owner);
    //The owner has to tell the platform that it has provided all the information needed in order for the project to go live
    function projectReady()external;
    //Once all the necessary information has been provided and the project is ready to go an event is ommited
    event newProjectConfirmed(string _ProjectName);

    //Users can be added
    function addUser()external;
    //Users can delete their own account
    function deleteAccount()external;

}
