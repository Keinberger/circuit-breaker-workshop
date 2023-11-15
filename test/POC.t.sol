// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/circuit-breaker/settlement/RejectSettlementModule.sol";
import "../src/circuit-breaker/core/CircuitBreaker.sol";
import "../src/Replica/packages/contracts-core/contracts/Replica.sol";
import "../src/Replica/packages/contracts-bridge/contracts/BridgeRouter.sol";

import "./utils/Attacker.sol";
import "./utils/Constants.sol";

// Foundry cheatsheet: https://github.com/foundry-rs/foundry/blob/master/forge/README.md#cheat-codes
// Foundry doc: https://book.getfoundry.sh

contract ReplicaPOC is Test, Constants {
   Replica replica = Replica(0xB92336759618F55bd0F8313bd843604592E27bd8);
   BridgeRouter bridgeRouter = BridgeRouter(payable(Constants.BRIDGE_ROUTER));
   Attacker attacker;
   address ADMIN = makeAddr("ADMIN");

   uint256 PRE_HACK_BLOCK = 15_259_100; // block before first hack

   function setUp() public {
      vm.createSelectFork('https://rpc.ankr.com/eth', PRE_HACK_BLOCK);

      attacker = new Attacker();

      vm.prank(ADMIN);
      // overriding bytecode
      BridgeRouter bridgeRouter = new BridgeRouter();
      vm.etch(Constants.BRIDGE_ROUTER_IMPL, address(bridgeRouter).code);
   }

   function addressToAssetId(address _addr) internal pure returns (bytes32) {
      return keccak256(abi.encodePacked(_addr));
   }

   function testReplicaPOCSetup() public {
      assert(address(replica) == 0xB92336759618F55bd0F8313bd843604592E27bd8);
      assertEq(block.number, PRE_HACK_BLOCK);
   }

   function testExploit() public {
      attacker.attack();
   }
}
