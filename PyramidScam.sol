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

    address constant Null = address(0);

    modifier ifOwner() {
        require(owner == msg.sender, "Only owner allowed");
        _;
    }

    modifier ifRecruiter() {
        require(address(recruiter) == msg.sender, "Only recruiter allowed");
        _;
    }

    constructor(PyramidScam scam, PyramidMember myRecruiter, address payable member, uint nInitialTokens) public {
        parentScam      = scam;
        recruiter       = myRecruiter;
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
        recruiter.updateChildren();

        selfdestruct(owner);
    }

    function updateRecruiter(PyramidMember newParent) public ifRecruiter {
        recruiter = newParent;
    }

    function updateChildren() public {
        for (uint i = 0; i < children.length; i++) {
            if (children[i] == PyramidMember(msg.sender)) {
                delete children[i];
                return;
            }
        }
    }

    function share() private {
        if (address(recruiter) == Null) return; // I'm the owner!!
        uint referralShare = msg.value / 2;
        address(recruiter).transfer(referralShare);
    }

    function() external payable {
        share();
    }

    function join() public payable returns(PyramidMember) {
        require(msg.value >= parentScam.joiningFee(), "go back with more money");

        share();
        PyramidMember newMember = parentScam.join.value(msg.value / 10)(msg.sender);
        children.push(newMember);
        return newMember;
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

    Kahlon private lottery;
    uint spentTokens = 0;

    address constant Null = address(0);

    function isMember(address user) private view returns (bool) {
        return AddressSet.contains(members, user);
    }

    modifier ifMember {
        require(isMember(msg.sender), "Only PyramidMember contract allowed");
        _;
    }

    modifier ifOwner {
        require(msg.sender == owner.owner(), "Only the owner allowed");
        _;
    }

    event NewMember (
        PyramidMember newMember
    );

    function addNewMember(address payable newAddress, PyramidMember recruiter) private returns(PyramidMember) {
        PyramidMember newMember = new PyramidMember(this, recruiter, newAddress, initialTokens);
        AddressSet.insert(members, address(newMember));

        addTokens(address(newMember), initialTokens);

        emit NewMember(newMember);
        return newMember;
    }

    constructor(uint _joiningFee) public {
        joiningFee = _joiningFee;
        owner = addNewMember(msg.sender, PyramidMember(address(0)));
        lottery = new Kahlon(3);
    }

    function join(address payable newAddress) public payable ifMember returns (PyramidMember) {
        return addNewMember(newAddress, PyramidMember(msg.sender));
    }

    function discardTokens(address who, uint howMany) private {
        tokens[who] -= howMany;
        nTokens -= howMany;
    }

    function addTokens(address who, uint howMany) private {
        tokens[who] += howMany;
        nTokens += howMany;
    }

    function spendTokensPrepare(bytes32 hashedTokens) public {
        lottery.enterHash(hashedTokens);
    }

    function spendTokens(uint8 revealedTokensNum) public {
        require(revealedTokensNum <= tokens[msg.sender], "not enough tokens");
        discardTokens(msg.sender, revealedTokensNum);
        spentTokens += revealedTokensNum;
        lottery.revealYourNumber(revealedTokensNum);
    }

    function startRevealStage() public ifOwner {
        lottery.secondRound();
    }

    event Winner(address winner);

    function rollTheDice() public ifOwner {
        address winner = lottery.determineWinner();
        emit Winner(winner);
        if (winner != Null) {
            uint tokenPrice = address(this).balance / (nTokens + spentTokens + 1);

            pendingWithdrawals[winner] += spentTokens * tokenPrice;
            nPending++;
        }
        lottery.destroy();
        lottery = new Kahlon(3);
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

contract Kahlon {

    mapping (uint8 => address[]) private playerByNumber ;
    mapping (address => bytes32) private playerHashes;

    uint8[] private numbers;

    address payable owner;

    uint public minPlayers;
    uint public nPlayers;

    enum State { Round1, Round2, Finished }

    State public state;

    modifier ifOwner() {
        require(owner == msg.sender, "Only owner allowed");
        _;
    }

    modifier ifRound1() {
        require(state == State.Round1, "invalid call for Round1");
        _;
    }

    modifier ifRound2() {
        require(state == State.Round2, "invalid call for Round2");
        _;
    }

    constructor(uint _minPlayers) public {
        owner = msg.sender;
        state = State.Round1;
        minPlayers = _minPlayers;
    }

    function hash(uint8 number, address addr) public pure returns(bytes32) {
        return sha256(abi.encodePacked(number, addr));
    }

    function enterHash(bytes32 x) public ifRound1 {
        playerHashes[msg.sender] = x;
        nPlayers++;
    }

    function secondRound() public ifRound1 {
        require(nPlayers >= minPlayers, "not enough players");
        state = State.Round2;
    }

    function revealYourNumber(uint8 number) public ifRound2 {
        require(hash(number, msg.sender) == playerHashes[msg.sender], "wrong seed");
        playerByNumber[number].push(msg.sender);
        numbers.push(number);
    }

    function determineWinner() public ifRound2 returns(address) {
        require(numbers.length >= minPlayers);
        state = State.Finished;
        address[] memory candidates = playerByNumber[random()];
        if (candidates.length == 1) {
            return candidates[0];
        }
        return address(0);
    }

    function destroy() public ifOwner {
        require(state == State.Finished, "must be Finished");
        selfdestruct(owner);
    }

    function random() private view returns (uint8) {
        uint8 randomNumber = uint8(0xDEAD);
        for (uint8 i = 0; i < numbers.length; ++i) {
            randomNumber ^= numbers[i];
        }
        return randomNumber;
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
