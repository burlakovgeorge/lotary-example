pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public usdEntryFee;
    uint256 public randomness;
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    //these 3 states represented by 0,1,2 respectively

    LOTTERY_STATE public lottery_state;

    uint256 public fee;
    bytes32 public keyhash; //provides a way to uniquely identify a chainline vrf node
    event RequestedRandomness(bytes32 requestId);

    constructor(
        address _priceFeedAddress, //needed to initialize constructor in this lottery.sol contract
        address _vrfCoordinator, //needed to initialize the inherited contract constructor
        address _link, //needed to initialize the inherited contract constructor
        uint256 _fee, //needed to set fee for contract which will be used by inherited contract functions
        bytes32 _keyhash //used in inherited vrf contract functions
    )  VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 1 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
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
        bytes32 requestId = requestRandomness(keyhash, fee);

        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        emit RequestedRandomness(requestId);
    }

    
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You arent there yet!"
        );
        require(_randomness > 0, "Randomness not found");
        //now we need to pick winner from players array
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        //ex of how this works
        //now we transfer entire balance of this contract into address of winner
        recentWinner.transfer(address(this).balance);

        //now we reset the lottery so it can be run again
        players = new address payable[](0);
        lottery_state == LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
}
