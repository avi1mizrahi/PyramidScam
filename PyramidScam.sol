pragma solidity >=0.5.0 <0.6.0;

contract PyramidMember {
    PyramidScam public parentScam;
    address     public owner;

    uint public _nTokens;
    uint public _tokenBuyPrice;
    uint public _tokenSellPrice;

    modifier ifOwner(){
        require(owner == msg.sender, "Only owner allowed");
        _;
    }

    constructor(PyramidScam scam, address member, uint nTokens) public {
        parentScam      = scam;
        owner           = member;
        _nTokens        = nTokens;
        _tokenBuyPrice  = 0;
        _tokenSellPrice = 2 ** 256 - 1;
    }

    function setBuyPrice(uint buyPrice) public ifOwner {
        _tokenBuyPrice = buyPrice;
    }

    function setSellPrice(uint sellPrice) public ifOwner {
        _tokenSellPrice = sellPrice;
    }

    function sell(uint nTokens, uint requestedPrice) public payable {
        require(requestedPrice >= _tokenSellPrice, "Go find yourself another seller");
        if (nTokens > _nTokens) nTokens = _nTokens;
        uint totalPrice = nTokens * requestedPrice;
        require(msg.value >= totalPrice, "come back with more money");

        _nTokens -= nTokens;

        parentScam.transfer(address(this), msg.sender, nTokens);

        msg.sender.transfer(msg.value - totalPrice); //TODO: vulnerability?
    }

    function buy(uint nTokens, uint requestedPrice) public {
        require(parentScam.getTokenAmount(msg.sender) >= nTokens, "Cheater");
        require(requestedPrice <= _tokenBuyPrice, "Go find yourself another buyer");
        uint totalPrice = nTokens * requestedPrice;
        require(totalPrice <= address(this).balance, "Sorry, out of money");

        parentScam.transfer(msg.sender, address(this), nTokens);
        _nTokens += nTokens;

        msg.sender.transfer(totalPrice); //TODO: vulnerability?
    }

    function getTokenAmount() public view returns (uint) {
        return parentScam.getTokenAmount(msg.sender);
    }
}

contract PyramidScam {

    address private owner;
    uint    private nPending = 0;
    uint    public  joiningFee;

    mapping(address => uint)    private _tokens;
    mapping(address => address) private affiliates;
    mapping(address => bool)    private members;
    mapping(address => uint)    private pendingWithdrawals;

    address constant Null = address(0);

    function isPyramidMemberContract(address user) private view returns (bool) {
        return members[user];
    }

    function isMember(address user) private view returns (bool) {
        return affiliates[user] != Null || user == owner;
    }

    modifier ifContractMember {
        require(isPyramidMemberContract(msg.sender), "Only PyramidMember contract allowed");
        _;
    }

    constructor(uint _joiningFee) public {
        owner = msg.sender;
        joiningFee = _joiningFee;
    }

    function join(address referral) public payable returns (PyramidMember) {
        require(msg.value >= joiningFee);
        require(!isMember(msg.sender));

        if (affiliates[referral] == Null)
            referral = owner;

        uint amount = joiningFee;
        while (referral != Null) {
            amount /= 2;
            if (amount == 0) break;
            if (pendingWithdrawals[referral] == 0)
                nPending++;
            pendingWithdrawals[referral] += amount;
            referral = affiliates[referral];
        }

        // TODO
        uint initialTokens = 1000;

        affiliates[msg.sender] = referral;
        PyramidMember newMember = new PyramidMember(this, msg.sender, initialTokens);
        members[address(newMember)] = true;
        _tokens[address(newMember)] = initialTokens;

        return newMember;
    }

    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];

        if (amount == 0)
            return;

        nPending--;
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks!
        pendingWithdrawals[msg.sender] = 0;
        if (nPending == 0) {
            // last one left wins the remainders
            selfdestruct(msg.sender);
        }

        msg.sender.transfer(amount);
    }

    function getTokenAmount(address addr) public view ifContractMember returns (uint) {
        return _tokens[addr];
    }

    function transfer(address from, address to, uint nTokens) public ifContractMember {
        // these sanity checks should never fail:
        assert(isPyramidMemberContract(from) || isPyramidMemberContract(to));
        assert(isMember(PyramidMember(msg.sender).owner()));
        assert(nTokens <= _tokens[from]);

        _tokens[from] -= nTokens;
        _tokens[to] += nTokens;
    }
}
