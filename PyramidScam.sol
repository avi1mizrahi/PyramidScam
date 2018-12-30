pragma solidity >=0.4.22 <0.6.0;


contract PyramidScam {
    uint constant public joiningFee;
    address private owner;
    uint private availableTokens;
    uint constant public tokenProducerPrice;
    uint constant public tokenConsumerPrice;
    mapping (address => address) private affiliates;
    mapping (address => uint)    pendingWithdrawals;
    mapping (address => uint)    pendingTokens;
    uint nPending = 0;

    address constant Null = address(0);
    
    
    modifier ifOwner(){
        if (owner != msg.sendr) {
           throw;
        }
        else{
           _;
        }
    }
      
    
    constructor(uint _joiningFee, uint _availableTokens, uint _tokenConsumerPrice, uint _tokenSupplierPrice) public {
        owner              = msg.sender;
        joiningFee         = _joiningFee;
        availableTokens    = _availableTokens;
        tokenConsumerPrice = _tokenConsumerPrice;
        tokenSupplierPrice = _tokenSupplierPrice;
    }

    function addTokens() ifOwner private payable {
        availableTokens += msg.value;
    }

    function buyTokensSupplier() public payable {
        uint payment;
        if (affiliates[msg.sender] != NULL) {
            payment = msg.value * tokenSupplierPrice;
            if (payment <= pendingWithdrawals[msg.sender]) {
                pendingTokens[msg.sender]      += msg.value;
                pendingWithdrawals[msg.sender] -= payment;
                pendingTokens[owner]           -= msg.value;
                pendingWithdrawals[owner]      += payment;
            }
        }
    }
    
     function buyTokensConsumer(address supplier) public payable returns (uint){
        uint tokenAmount = msg.value / tokenConsumerPrice;
        if (affiliates[supplier] != NULL) {
            if (tokenAmount <= pendingTokens[supplier]) {
                pendingTokens[supplier]        -= tokenAmount;
                pendingWithdrawals[supplier]   += msg.value;
                return tokenAmount;
            }
        }
        return 0;
    }
    
    function join(address referral) public payable {
        if (msg.value < joiningFee) return;
        if (affiliates[msg.sender] != Null || msg.sender == owner) return; // TODO: do better here
        if (affiliates[referral] == Null)
            referral = owner;

        affiliates[msg.sender] = referral;

        uint amount = joiningFee;
        while(referral != Null) {
            amount /= 2;
            if (pendingWithdrawals[referral] == 0 && amount > 0)
                nPending++;
            pendingWithdrawals[referral] += amount;
            referral = affiliates[referral];
        }
        
        uint initialDeposit = msg.value - joiningFee;
        uint initialTokens  = initialDeposit/tokenSupplierPrice;
        pendingTokens[msg.sender] = initialTokens;
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
