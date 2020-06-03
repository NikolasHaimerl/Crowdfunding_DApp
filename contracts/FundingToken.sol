pragma solidity ^0.6.0;

import "./ERC223/token/ERC223/ERC223.sol";
import "./ERC223/token/ERC223/ERC223Mintable.sol";
import "./ERC223/token/ERC223/ERC223Burnable.sol";



contract FundingToken is ERC223Token,ERC223Mintable,ERC223Burnable {
    using SafeMath for uint;
    uint public current_price_new_token;
    mapping(address  =>uint256) public price_offer;
    mapping(address =>uint256) public price_bidding;
    mapping(uint256=>address payable) public highest_bidder_for_amount;
    mapping(uint256=>address payable) public lowest_offer_for_amount;
    mapping(address=>bool)public offerer_can_get_redemption;
    mapping(address=>bool)public bidder_can_get_bid_back;
    mapping(address=>uint256)public redemption_value;
    mapping(address=>uint256)public payback;

uint256 public cost_auction_use;
    bool public auction_ready=false;


    modifier auctionReady(){
        require(auction_ready);
        _;
    }

    function getPayback()external{
        if(bidder_can_get_bid_back[msg.sender]){
            msg.sender.transfer(payback[msg.sender]);
        }
    }

    function redemption()external{
        if(offerer_can_get_redemption[msg.sender]){
            msg.sender.transfer(redemption_value[msg.sender]);
        }
    }

    function setcostofAuction(uint256 _amount)external onlyMinter{
        cost_auction_use=_amount;
    }


    function setpriceNewToken(uint _new)external onlyMinter{
        current_price_new_token=_new;
    }

    function startAuction(uint256 _curr)external onlyMinter{
        current_price_new_token=_curr;
        auction_ready=true;
    }
    function bid(uint256 _price,uint256 _amount)external payable auctionReady{
        require(msg.value>=cost_auction_use);
        require(msg.value>=(cost_auction_use.add(_price.mul(_amount))));
        address payable offerer=lowest_offer_for_amount[_amount];
        uint256 lowest=price_offer[lowest_offer_for_amount[_amount]];
        uint256 highest=price_bidding[highest_bidder_for_amount[_amount]];
        address payable highest_bidder=highest_bidder_for_amount[_amount];
        if(_price >=current_price_new_token&&_balances[address(this)]>=_amount){
            _balances[address(this)]=_balances[address(this)].sub(_amount);
            _balances[msg.sender]=_balances[msg.sender].add(_amount);
        }
        else if(_price>=lowest&&_balances[offerer]>=_amount&&lowest!=0){
            _balances[offerer]=_balances[offerer].sub(_amount);
            _balances[msg.sender]=_balances[msg.sender].add(_amount);
            offerer_can_get_redemption[offerer]=true;
            redemption_value[offerer]=lowest;


        }
        else if(_price>highest){
                highest_bidder_for_amount[_amount]=msg.sender;
                price_bidding[msg.sender]=_price;
                bidder_can_get_bid_back[highest_bidder]=true;
                payback[highest_bidder]=highest;
            }
        else{
            msg.sender.transfer(msg.value.sub(cost_auction_use));
        }
    }

    function makeOffer(uint256 _price,uint256 _amount)external payable auctionReady{
        require(msg.value>=cost_auction_use);
        require(_balances[msg.sender]>=_amount);
        uint256 lowest=price_offer[lowest_offer_for_amount[_amount]];
        address payable lowest_offerer=lowest_offer_for_amount[_amount];
        address payable bidder=highest_bidder_for_amount[_amount];
        uint256 highest=price_bidding[highest_bidder_for_amount[_amount]];
        if(_price<=highest){
            _balances[msg.sender]=_balances[msg.sender].sub(_amount);
            _balances[bidder]=_balances[bidder].add(_amount);
            offerer_can_get_redemption[msg.sender]=true;
            redemption_value[msg.sender]=_price;
        }

        else if(lowest==0||lowest>_price){
            lowest_offer_for_amount[_amount]=msg.sender;
            price_offer[msg.sender]=_price;
        }




    }



}

