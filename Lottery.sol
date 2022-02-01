pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./RNG.sol";

contract Lottery is Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public usdEntryFee;

    AggregatorV3Interface internal ethUsdPriceFeed;

     RNG public randomRNG;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    //these 3 states represented by 0,1,2 respectively

    LOTTERY_STATE public lottery_state;

     event RequestedRandomness(bytes32 requestId);

    constructor(
        address _priceFeedAddress, //needed to initialize constructor in this lottery.sol contract
        address RNGContract
    )  {
        usdEntryFee = 1 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomRNG = RNG(RNGContract);
    }

    function enter() public payable {
        //min 1USD in eth entrance
        //this function declared payable thus
        //automatically it will take any "value" sent in call
        //and hold it in the contract address balance
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "You need more Eth!");
        players.push(payable(msg.sender));
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        uint256 costToEnter = (usdEntryFee * 10**21) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Cant start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        //when ending lotto must first ensure we were in open state
        //then we will choose a random winner
        //finally we will set lottery to closed
        require(lottery_state == LOTTERY_STATE.OPEN);
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        //need to now request a random number
        //call request randomness function from VRFConsumer base
        //it returns a bytes32 type
        bytes32 requestId = randomRNG.requestRandomNumber();

        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        emit RequestedRandomness(requestId);
    }

    
    function findWinner(bytes32 _requestId)
        public onlyOwner
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You arent there yet!"
        );

        uint256 indexOfWinner = randomRNG.winners(_requestId) % players.length;
        recentWinner = players[indexOfWinner];
        //ex of how this works
        //now we transfer entire balance of this contract into address of winner
        recentWinner.transfer(address(this).balance);

        //now we reset the lottery so it can be run again
        players = new address payable[](0);
        lottery_state == LOTTERY_STATE.CLOSED;

    }

    function setRNGContract(address RNGContract) public onlyOwner {
       randomRNG = RNG(RNGContract);
    }
}
