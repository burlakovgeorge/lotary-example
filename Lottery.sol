pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./RNG.sol";
import "./SortitionSumTreeFactory.sol";


library UniformRandomNumber {
  /// @notice Select a random number without modulo bias using a random seed and upper bound
  /// @param _entropy The seed for randomness
  /// @param _upperBound The upper bound of the desired number
  /// @return A random number less than the _upperBound
  function uniform(uint256 _entropy, uint256 _upperBound) internal pure returns (uint256) {
    require(_upperBound > 0, "UniformRand/min-bound");
    uint256 min = 0 - _upperBound % _upperBound;
    uint256 random = _entropy;
    while (true) {
      if (random >= min) {
        break;
      }
      random = uint256(keccak256(abi.encodePacked(random)));
    }
    return random % _upperBound;
  }
}


contract Lottery is Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public usdEntryFee;

    AggregatorV3Interface internal ethUsdPriceFeed;

     RNG public randomRNG;

     bytes32 constant private TREE_KEY = keccak256("Lottery");
    uint256 constant private MAX_TREE_LEAVES = 5;

    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    SortitionSumTreeFactory.SortitionSumTrees sumTreeFactory;

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
        require(lottery_state == LOTTERY_STATE.OPEN);
        // require(msg.value >= getEntranceFee(), "You need more Eth!");
        // players.push(payable(msg.sender));
        sumTreeFactory.set(TREE_KEY, msg.value, bytes32(uint256(uint160(address(msg.sender)))));
    }


    function startLottery() public {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Cant start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
        sumTreeFactory.createTree(TREE_KEY, MAX_TREE_LEAVES);
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
        
        
        bytes32 entropy = blockhash(1);
        uint256 token = UniformRandomNumber.uniform(uint256(entropy), uint(_requestId));
        
        recentWinner = payable(address(uint160(bytes20(sumTreeFactory.draw(TREE_KEY, token)))));
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
