pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RNG is VRFConsumerBase, Ownable {

    uint256 public fee;
    bytes32 public keyhash; //provides a way to uniquely identify a chainline vrf node
   
  mapping(bytes32 => uint256) public winners;



    constructor(
        address _vrfCoordinator, //needed to initialize the inherited contract constructor
        address _link, //needed to initialize the inherited contract constructor
         uint256 _fee, //needed to set fee for contract which will be used by inherited contract functions
        bytes32 _keyhash //used in inherited vrf contract functions
    
    )  VRFConsumerBase(_vrfCoordinator, _link) {
        fee = _fee;
        keyhash = _keyhash;
    }

    function requestRandomNumber() public  returns(bytes32) {
        return requestRandomness(keyhash, fee);
    }


    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal override
    {
   
        require(_randomness > 0, "Randomness not found");
        //now we need to pick winner from players array
       winners[_requestId]=_randomness;
    }



}