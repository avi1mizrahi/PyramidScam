pragma solidity >=0.4.22 <0.6.0;


contract PyramidScam {
    uint constant public joiningFee = 1 ether;
    address private owner;
    mapping (address => address) private affiliates;
    mapping (address => uint) pendingWithdrawals;
    uint nPending = 0;

    address constant Null = address(0);

    constructor() public {
        owner = msg.sender;
    }

    function join(address referral) public payable {
        if (msg.value < joiningFee) return;
        if (affiliates[msg.sender] != Null || msg.sender == owner) return; // TODO: do better here
        if (affiliates[referral] == Null)
            referral = owner;

        affiliates[msg.sender] = referral;

        uint amount = msg.value;
        while(referral != Null) {
            amount /= 2;
            if (pendingWithdrawals[referral] == 0 && amount > 0)
                nPending++;
            pendingWithdrawals[referral] += amount;
            referral = affiliates[referral];
        }
    }

    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];

        if (amount == 0)
            return;

        nPending--;
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        if (nPending == 0) {
            // last one left
            selfdestruct(msg.sender);
        } else {
            msg.sender.transfer(amount);
        }
    }
}
