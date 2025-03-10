// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract RPSLS {
    enum State { WaitingForPlayers, WaitingForCommits, WaitingForReveals, Finished }
    State public gameState;

    address[] public players;
    uint public reward;
    uint public numPlayers;

    uint public revealDeadline;
    uint constant REVEAL_PERIOD = 1 days;

    mapping(address => bool) public allowedPlayers;

    // สำหรับ commit–reveal
    mapping(address => bytes32) public commitments;
    mapping(address => bool) public hasCommitted;
    mapping(address => uint) public revealedChoice; // 0: Rock, 1: Spock, 2: Paper, 3: Lizard, 4: Scissors
    mapping(address => bool) public hasRevealed;

    mapping(address => bool) public withdrawn;
    uint public countWithdrawn;

    constructor() {
        // บัญชีที่จะให้เล่นได้
        allowedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        allowedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        allowedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        allowedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
        gameState = State.WaitingForPlayers;
    }

    function addPlayer() public payable {
        require(gameState == State.WaitingForPlayers, "Game not in registration state");
        require(allowedPlayers[msg.sender], "Not allowed player");
        require(msg.value == 1 ether, "Must send 1 ether");

        for (uint i = 0; i < players.length; i++) {
            require(players[i] != msg.sender, "Player already added");
        }
        players.push(msg.sender);
        reward += msg.value;
        numPlayers++;

        if (numPlayers == 2) {
            gameState = State.WaitingForCommits;
        }
    }

    function commit(bytes32 _commitment) public {
        require(gameState == State.WaitingForCommits, "Not in commit phase");
        require(isPlayer(msg.sender), "Not a registered player");
        require(!hasCommitted[msg.sender], "Already committed");
        commitments[msg.sender] = _commitment;
        hasCommitted[msg.sender] = true;

        if (hasCommitted[players[0]] && hasCommitted[players[1]]) {
            gameState = State.WaitingForReveals;
            revealDeadline = block.timestamp + REVEAL_PERIOD;
        }
    }

    // 0: Rock, 1: Spock, 2: Paper, 3: Lizard, 4: Scissors
    function reveal(uint _choice, string memory salt) public {
        require(gameState == State.WaitingForReveals, "Not in reveal phase");
        require(isPlayer(msg.sender), "Not a registered player");
        require(hasCommitted[msg.sender], "Haven't committed yet");
        require(!hasRevealed[msg.sender], "Already revealed");
        require(_choice <= 4, "Invalid choice");

        require(keccak256(abi.encodePacked(_choice, salt)) == commitments[msg.sender], "Invalid reveal");

        revealedChoice[msg.sender] = _choice;
        hasRevealed[msg.sender] = true;

        if (hasRevealed[players[0]] && hasRevealed[players[1]]) {
            _checkWinnerAndPay();
        }
    }

    function claimTimeout() public {
        require(gameState == State.WaitingForReveals, "Not in reveal phase");
        require(block.timestamp > revealDeadline, "Reveal period not over");
        require(isPlayer(msg.sender), "Not a registered player");

        address other = (players[0] == msg.sender) ? players[1] : players[0];
        bool meRevealed = hasRevealed[msg.sender];
        bool otherRevealed = hasRevealed[other];

        if (meRevealed && !otherRevealed) {
            
            uint amount = reward;
            reward = 0;
            payable(msg.sender).transfer(amount);
            gameState = State.Finished;
            resetGame();
        } else if (!meRevealed && !otherRevealed) {
            
            require(!withdrawn[msg.sender], "Already withdrawn");
            withdrawn[msg.sender] = true;
            payable(msg.sender).transfer(1 ether);
            countWithdrawn++;
            if (countWithdrawn == 2) {
                gameState = State.Finished;
                resetGame();
            }
        } else {
            revert("Cannot claim timeout");
        }
    }

   
    function _checkWinnerAndPay() private {
        uint choice0 = revealedChoice[players[0]];
        uint choice1 = revealedChoice[players[1]];

        if (choice0 == choice1) {
            
            payable(players[0]).transfer(reward / 2);
            payable(players[1]).transfer(reward / 2);
        } else {
            uint diff = (5 + choice0 - choice1) % 5;
            if (diff == 1 || diff == 2) {
                payable(players[0]).transfer(reward);
            } else {
                payable(players[1]).transfer(reward);
            }
        }
        gameState = State.Finished;
        resetGame();
    }

    
    function isPlayer(address addr) private view returns (bool) {
        return (players.length > 0 && (players[0] == addr || (players.length > 1 && players[1] == addr)));
    }

    
    function resetGame() private {
        
        delete players;
        reward = 0;
        numPlayers = 0;
        gameState = State.WaitingForPlayers;
        
    }
}
