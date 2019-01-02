pragma solidity >=0.5.0 <0.6.0;

library AddressSet {
    struct Set {
        mapping(address => bool) contained;
    }

    function insert(Set storage self, address value) public returns (bool) {
        if (self.contained[value])
            return false; // already there
        self.contained[value] = true;
        return true;
    }

    function remove(Set storage self, address value) public returns (bool) {
        if (!self.contained[value])
            return false; // not there
        self.contained[value] = false;
        return true;
    }

    function contains(Set storage self, address value) public view returns (bool) {
        return self.contained[value];
    }
}

contract PyramidMember {
    PyramidScam     public parentScam;
    address payable public owner;

    uint public nTokens;
    uint public tokenBuyPrice;
    uint public tokenSellPrice;

    modifier ifOwner() {
        require(owner == msg.sender, "Only owner allowed");
        _;
    }

    modifier ifParent() {
        require(address(parentScam) == msg.sender, "Only parentScam allowed");
        _;
    }

    constructor(PyramidScam scam, address payable member, uint nInitialTokens) public {
        parentScam      = scam;
        owner           = member;
        nTokens         = nInitialTokens;
        tokenBuyPrice   = 0;
        tokenSellPrice  = 2 ** 256 - 1;
    }

    function destroy() public ifParent {
        selfdestruct(owner);
    }

    function setBuyPrice(uint buyPrice) public ifOwner {
        tokenBuyPrice = buyPrice;
    }

    function setSellPrice(uint sellPrice) public ifOwner {
        tokenSellPrice = sellPrice;
    }

    function sell(uint numTokensToGet, uint requestedPrice) public payable {
        require(requestedPrice >= tokenSellPrice, "Go find yourself another seller");
        if (numTokensToGet > nTokens) numTokensToGet = nTokens;
        uint totalPrice = numTokensToGet * requestedPrice;
        require(msg.value >= totalPrice, "come back with more money");

        nTokens -= numTokensToGet;

        parentScam.transfer(address(this), msg.sender, numTokensToGet);

        msg.sender.transfer(msg.value - totalPrice); //TODO: vulnerability?
    }

    function buy(uint numTokensToGive, uint requestedPrice) public {
        require(parentScam.getTokenAmount(msg.sender) >= numTokensToGive, "Cheater");
        require(requestedPrice <= tokenBuyPrice, "Go find yourself another buyer");
        uint totalPrice = numTokensToGive * requestedPrice;
        require(totalPrice <= address(this).balance, "Sorry, out of money");

        parentScam.transfer(msg.sender, address(this), numTokensToGive);
        nTokens += numTokensToGive;

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

    uint                        private nTokens;
    mapping(address => uint)    private tokens;
    mapping(address => address) private affiliates;
    AddressSet.Set              private members;
    mapping(address => uint)    private pendingWithdrawals;

    address constant Null = address(0);

    function isPyramidMemberContract(address user) private view returns (bool) {
        return AddressSet.contains(members, user);
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
        joiningFee = 1 ether; // TODO:delete
    }

    event Join (
        PyramidMember newMember
    );

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
        AddressSet.insert(members, address(newMember));
        tokens[address(newMember)] = initialTokens;
        nTokens += initialTokens;

        emit Join(newMember);
        return newMember;
    }

    function spendToken() public pure returns(uint) {
        // TODO: do the "coinflip" here
        // return _tokens[addr];
        return 0; // TODO
    }

    function exitAndWithdraw() public {
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
        return tokens[addr];
    }

    event Transfer (
        address _from,
        address _to,
        address _sender,
        uint _nTokens
    );

    function transfer(address from, address to, uint numTokens) public ifContractMember {
        emit Transfer(from, to , msg.sender, nTokens);
        // these sanity checks should never fail:
        require(isPyramidMemberContract(from) || isPyramidMemberContract(to), "member must touch is own pot");
        // TODO: there is a bug! enable this check:
        // require(isMember(PyramidMember(msg.sender).owner()), "sender is not a PyramidMember of this");
        require(nTokens <= tokens[from], "not enough tokens");

        tokens[from] -= numTokens;
        tokens[to] += numTokens;
    }
}
