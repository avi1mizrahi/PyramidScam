pragma solidity >=0.5.0 <0.6.0;

contract PyramidMember {
    // TODO: all public for testing
    address payable public  owner;
    PyramidScam     public  parentScam;
    PyramidMember   public  recruiter;
    PyramidMember[] public  children;

    uint public nTokens;
    uint public tokenBuyPrice;
    uint public tokenSellPrice;

    modifier ifOwner() {
        require(owner == msg.sender, "Only owner allowed");
        _;
    }

    modifier ifRecruiter() {
        require(address(recruiter) == msg.sender, "Only recruiter allowed");
        _;
    }

    constructor(PyramidScam scam, address payable member, uint nInitialTokens) public {
        parentScam      = scam;
        owner           = member;
        nTokens         = nInitialTokens;
        tokenBuyPrice   = 0;
        tokenSellPrice  = 2 ** 256 - 1;
    }

    function exit() public {
        parentScam.exit();

        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < children.length; i++) {
            children[i].updateRecruiter(recruiter);
        }

        selfdestruct(owner);
    }

    function updateRecruiter(PyramidMember newParent) public ifRecruiter {
        recruiter = newParent;
    }

    function share() private {
        uint referralShare = msg.value / 2;
        address(recruiter).transfer(referralShare);
    }

    function() external payable {
        share();
    }

    function join() public payable returns(PyramidMember) {
        require(msg.value >= parentScam.joiningFee(), "go back with more money");

        share();
        return parentScam.join.value(msg.value / 10)(msg.sender);
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

    PyramidMember public  owner;
    uint          public  joiningFee;
    // TODO
    uint          public  initialTokens = 1000;

    uint                        private nTokens;
    mapping(address => uint)    private tokens;
    uint                        private nPending = 0;
    mapping(address => uint)    private pendingWithdrawals;
    AddressSet.Set              private members;

    address constant Null = address(0);

    function isMember(address user) private view returns (bool) {
        return AddressSet.contains(members, user);
    }

    modifier ifMember {
        require(isMember(msg.sender), "Only PyramidMember contract allowed");
        _;
    }

    event NewMember (
        PyramidMember newMember
    );

    function addNewMember(address payable newAddress) private returns(PyramidMember) {
        PyramidMember newMember = new PyramidMember(this, newAddress, initialTokens);
        AddressSet.insert(members, address(newMember));

        tokens[address(newMember)] = initialTokens;
        nTokens += initialTokens;

        emit NewMember(newMember);
        return newMember;
    }

    constructor(uint _joiningFee) public {
        joiningFee = _joiningFee;
        owner = addNewMember(msg.sender);
    }

    function join(address payable newAddress) public payable ifMember returns (PyramidMember) {
        return addNewMember(newAddress);
    }

    function spendToken() public pure returns(uint) {

        // TODO: do the "coinflip" here
        // return _tokens[addr];
        return 0; // TODO
    }

    function isEmpty() private view returns(bool) {
        return AddressSet.isEmpty(members) && nPending == 0;
    }

    function exit() public ifMember {
        AddressSet.remove(members, msg.sender);
        if (isEmpty()) selfdestruct(msg.sender);
    }

    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];

        if (amount == 0)
            return;

        nPending--;
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks!
        pendingWithdrawals[msg.sender] = 0;
        if (isEmpty()) {
            // last one left wins the remainders
            selfdestruct(msg.sender);
        }

        msg.sender.transfer(amount);
    }

    function getTokenAmount(address addr) public view ifMember returns (uint) {
        return tokens[addr];
    }

    event Transfer (
        address _from,
        address _to,
        address _sender,
        uint _nTokens
    );

    function transfer(address from, address to, uint numTokens) public ifMember {
        emit Transfer(from, to , msg.sender, nTokens);
        // these sanity checks should never fail:
        require(isMember(from) || isMember(to), "member must touch is own pot");
        // TODO: there is a bug! enable this check:
        // require(isMember(PyramidMember(msg.sender).owner()), "sender is not a PyramidMember of this");
        require(nTokens <= tokens[from], "not enough tokens");

        tokens[from] -= numTokens;
        tokens[to] += numTokens;
    }
}

library AddressSet {
    struct Set {
        uint size;
        mapping(address => bool) contained;
    }

    function insert(Set storage self, address value) public returns (bool) {
        if (self.contained[value])
            return false; // already there
        self.contained[value] = true;
        self.size++;
        return true;
    }

    function remove(Set storage self, address value) public returns (bool) {
        if (!self.contained[value])
            return false; // not there
        self.contained[value] = false;
        self.size--;
        return true;
    }

    function contains(Set storage self, address value) public view returns (bool) {
        return self.contained[value];
    }

    function isEmpty(Set storage self) public view returns (bool) {
        return self.size == 0;
    }
}
