pragma solidity ^0.4.19;

import "./GroupAdmin.sol";
import "./zeppelin/lifecycle/Destructible.sol";


contract Conference is Destructible, GroupAdmin {

    ////////////////////////////////////////////////////////////////////////////
    // Attributes
    ////////////////////////////////////////////////////////////////////////////

    string public name;
    uint256 public deposit;
    uint public limitOfParticipants;
    uint public registered;
    uint public attended;
    bool public ended;
    bool public cancelled;
    uint public endedAt;
    uint public coolingPeriod;
    uint256 public payoutAmount;
    string public encryption;

    bool private paid;

    mapping (address => Participant) public participants;
    mapping (uint => address) public participantsIndex;

    ////////////////////////////////////////////////////////////////////////////
    // Structs
    ////////////////////////////////////////////////////////////////////////////

    struct Participant {
        string participantName;
        address addr;
        address manager;
        bool attended;
        bool paid;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////

    event RegisterEvent(
        address addr,
        string participantName,
        string _encryption
    );
    event AttendEvent(address addr);
    event PaybackEvent(uint256 _payout);
    event WithdrawEvent(address addr, uint256 _payout);
    event CancelEvent();
    event ClearEvent(address addr, uint256 leftOver);

    ////////////////////////////////////////////////////////////////////////////
    // Modifiers
    ////////////////////////////////////////////////////////////////////////////

    modifier onlyActive {
        require(!ended);
        _;
    }

    modifier onlyEnded {
        require(ended);
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // External functions
    ////////////////////////////////////////////////////////////////////////////

    function Conference (
        string _name,
        uint256 _deposit,
        uint _limitOfParticipants,
        uint _coolingPeriod,
        string _encryption
    ) public {
        require(bytes(_name).length > 0);
        require(_deposit != 0);
        require(_limitOfParticipants != 0);
        require(_coolingPeriod != 0);

        name = _name;
        deposit = _deposit;
        limitOfParticipants = _limitOfParticipants;
        coolingPeriod = _coolingPeriod;

        if (bytes(_encryption).length != 0) {
            encryption = _encryption;
        }
    }

    function registerWithEncryption(address _addr, string _name, string _encrypted)
    external payable onlyActive {
        registerInternal(_addr, _name);
        RegisterEvent(_addr, _name, _encrypted);
    }

    function register(address _addr, string _name)
    external payable onlyActive {
        registerInternal(_addr, _name);
        RegisterEvent(_addr, _name, "");
    }

    function withdraw(address _addr) external onlyEnded {
        require(payoutAmount > 0);

        Participant storage participant = participants[_addr];
        require(
            participant.addr == msg.sender ||
            participant.manager == msg.sender
        );
        require(cancelled || participant.attended);
        require(participant.paid == false);

        participant.paid = true;
        participant.addr.transfer(payoutAmount);
        WithdrawEvent(msg.sender, payoutAmount);
    }

    function payback() external onlyOwner onlyActive {
        payoutAmount = payout();
        ended = true;
        endedAt = now;
        PaybackEvent(payoutAmount);
    }

    function cancel() external onlyOwner onlyActive {
        payoutAmount = deposit;
        cancelled = true;
        ended = true;
        endedAt = now;
        CancelEvent();
    }

    function clear() external onlyOwner onlyEnded {
        require(now > endedAt + coolingPeriod);
        require(ended);

        uint256 leftOver = totalBalance();
        owner.transfer(leftOver);
        ClearEvent(owner, leftOver);
    }

    function setLimitOfParticipants(uint _limitOfParticipants)
    external onlyOwner onlyActive {
        limitOfParticipants = _limitOfParticipants;
    }

    function attend(address[] _addresses) external onlyAdmin onlyActive {
        for (uint i = 0; i < _addresses.length; i++) {
            address _addr = _addresses[i];
            require(isRegistered(_addr));
            require(!isAttended(_addr));
            participants[_addr].attended = true;
            attended++;
            AttendEvent(_addr);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // Public functions
    ////////////////////////////////////////////////////////////////////////////

    function totalBalance() public constant returns (uint256) {
        return address(this).balance;
    }

    function isRegistered(address _addr) public constant returns (bool) {
        return participants[_addr].addr != address(0);
    }

    function isAttended(address _addr) public constant returns (bool) {
        return isRegistered(_addr) && participants[_addr].attended;
    }

    function isPaid(address _addr) public constant returns (bool) {
        return isRegistered(_addr) && participants[_addr].paid;
    }

    function payout() public constant returns(uint256) {
        if (attended == 0) return 0;
        return uint(totalBalance()) / uint(attended);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Internal functions
    ////////////////////////////////////////////////////////////////////////////

    function registerInternal(address _addr, string _name) internal {
        require(msg.value == deposit);
        require(registered < limitOfParticipants);
        require(!isRegistered(_addr));

        registered++;
        participantsIndex[registered] = _addr;
        participants[_addr] =
            Participant(_name, _addr, msg.sender, false, false);
    }
}
