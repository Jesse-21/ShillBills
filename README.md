# ShillBills
This is the primary location for code related to the ShillBills Multi-Utillity Token
and it's various other parts like UI on frontend, dao related code/info, and more.
We will do our best to keep this updated.  If you run a platform or token list,
Please add us using the info in "token-list-info".

________________________________________________________
----//  About The Fee Lotto in the smart contract //----

---Explained---

--Fee Accumulation--

A fee of 0.1% (feeRate = 10) is taken from every transaction and added to accumulatedFees.
The net amount after the fee is transferred to the recipient.


--Lottery Trigger--

When accumulatedFees reaches or exceeds lotteryThreshold, a lottery is triggered.

--Random Winner Selection--

A pseudo-random number is generated using block data to select a random winner from the holders list.
The accumulated fees are transferred to the winner, and accumulatedFees is reset.
Holders Tracking:

The contract keeps track of token holders in the holders array. New holders are added when they first receive tokens.

--Security:--

The nonReentrant modifier is used to prevent reentrancy attacks.
Pseudo-random number generation is used

___________________________________________________________________
-----To sustain this fee returns action in the smart contract:-----

Only 75% of the accumulated fees are distributed to the winner. 
The remaining 25% will stay in the contract to help cover gas.  
This is not touched by the team, it never will be. 
Anything remaining will be part of the next lotto that happens 
and then auto-repeats indef.
___________________________________________________________________
