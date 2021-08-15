// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import './Ownable.sol';

contract SavingGroups is Ownable{
    enum Stages {
        //Stages of the round
        Setup,
        Save,
        Finished
    }

    struct User {
        //Information from each user
        address payable userAddr;
        bool saveAmountFlag;
        bool currentRoundFlag; //defines if the user is participating in the current round
        uint8 latePayments;
    }

    mapping(address => User) public users;
    address payable public admin; //The user that deploy the contract is the administrator

    //Constructor deployment variables
    uint256 cashIn; //amount to be payed as commitment at the begining of the saving circle
    uint256 saveAmount; //Payment on each round/cycle
    uint256 public groupSize; //Number of slots for users to participate on the saving circle

    //Counters and flags
    uint256 usersCounter = 0;
    uint256 public turn = 1; //Current cycle/round in the saving circle
    uint256 public startTime;
    uint256 public totalSaveAmount = 0; //Collective saving on the round
    uint256 public totalCashIn = 0;
    uint256 public cashOutUsers;
    uint256 cashOut=0;
    address[] public addressOrderList;
    uint256[] public latePaymentsList;
    Stages public stage;

    //Time constants in seconds
    // Weekly by Default
    uint256 public payTime = 86400 * 7;
    uint256 public withdrawTime = 86400 * 7;

    constructor(
        uint256 _cashIn,
        uint256 _saveAmount,
        uint256 _groupSize,
        address payable _admin,
        uint256 _payTime,
        uint256 _withdrawTime
    ) public {
        admin = _admin;
        cashIn = _cashIn * 1e17;
        saveAmount = _saveAmount * 1e17;
        groupSize = _groupSize;
        cashOutUsers = 0;
        stage = Stages.Setup;
        addressOrderList = new address[](_groupSize);
        latePaymentsList = new uint256[](_groupSize);
        require(_payTime > 0, "El tiempo para pagar no puede ser menor a un dia");
        require(_withdrawTime > 0, "El tiempo para retirar los fondos no puede ser menor a un dia");
        payTime = 86400 * _payTime;
        withdrawTime = 86400 * _withdrawTime;
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    function registerUser(uint256 _usrTurn)
        public
        payable
        isPayAmountCorrect(msg.value, cashIn)
        atStage(Stages.Setup)
    {
        require(usersCounter < groupSize, "El grupo esta completo"); //the saving circle is full
        require(addressOrderList[_usrTurn-1]==address(0), "Este lugar ya esta ocupado" );
        usersCounter++;
        totalCashIn = totalCashIn + msg.value;
        cashOutUsers++;
        users[msg.sender] = User(
            msg.sender,
            false,
            true,
            0
        );
        addressOrderList[_usrTurn-1]=msg.sender; //store user
    }

    function removeUser(uint256 _usrTurn)
        public
        payable
        onlyAdmin(admin)
        atStage(Stages.Setup)
    {
      require(addressOrderList[_usrTurn-1]!=address(0), "Este turno esta vacio");
      address removeAddress=addressOrderList[_usrTurn-1];
      if(users[removeAddress].latePayments == 0){
          totalCashIn = totalCashIn - cashIn;
          users[removeAddress].userAddr.transfer(cashIn);
      }
      addressOrderList[_usrTurn-1]=address(0);
      usersCounter--;
      cashOutUsers--;
      users[removeAddress].currentRoundFlag = false;
    }

    function startRound()
        public
        onlyAdmin(admin)
        atStage(Stages.Setup)
    {
        require(cashOutUsers == groupSize, "Aun hay lugares sin asignar o alguien no ha pagado la garantia");
        stage = Stages.Save;
        startTime= block.timestamp;
    }

    function payTurn()
        public
        payable
        isRegisteredUser(users[msg.sender].currentRoundFlag)
        isPayAmountCorrect(msg.value, cashIn)
        isNotUsersTurn(addressOrderList[turn - 1])
        atStage(Stages.Save)
    {
        //users make the payment for the cycle
        require(
            users[msg.sender].saveAmountFlag == false,
            "Ya ahorraste este turno"
        ); //you have already saved this round
         if(block.timestamp > startTime + turn*payTime + (turn-1)*withdrawTime) {
            payLateTurn();
        } else {
            totalSaveAmount = totalSaveAmount + msg.value;
            users[msg.sender].saveAmountFlag = true;
        }
    }

    function payLateTurn()
        public
        payable
        isRegisteredUser(users[msg.sender].currentRoundFlag)
        isPayAmountCorrect(msg.value, cashIn)
        atStage(Stages.Save)
    {
        //users make the payment for the cycle
        require(
            users[msg.sender].latePayments > 0,
            "Estas al corriente en pagos"
        ); //you have already saved this round
        totalCashIn = totalCashIn + msg.value;
        users[msg.sender].latePayments--;
        updateLatePayments();
        if (users[msg.sender].latePayments == 0) { //Issue: si alguien se pone al corriente pero hay alguien mas atrazado no se prende su bandera
            cashOutUsers++;
        }
    }

    function withdrawTurn()
        public
        payable
        isRegisteredUser(users[msg.sender].currentRoundFlag)
        atStage(Stages.Save)
        isUsersTurn(addressOrderList[turn - 1])
    {
        require(block.timestamp <= startTime + turn*payTime + turn*withdrawTime , "Termino el tiempo de retiro");
        if (
            startTime + turn*payTime + (turn-1)*withdrawTime < block.timestamp && totalSaveAmount < (groupSize-1) * saveAmount
        ) {
            findLateUser();
        }
        require(
            totalSaveAmount == (groupSize-1) * saveAmount,
            "Espera a que tengamos el monto de tu ahorro"
        ); //Se debe estar en fase de pago
        address addressUserInTurn = addressOrderList[turn - 1];
        users[addressUserInTurn].userAddr.transfer(totalSaveAmount);
        totalSaveAmount = 0;
        if (turn >= groupSize) {
            stage = Stages.Finished;
        } else {
            newTurn();
        }
        turn++;
    }

    function newTurn() private {
        //repeats the save and pay stages according to the saving circle size
        for (uint8 i = 0; i < groupSize; i++) {
            address useraddress = addressOrderList[i];
            users[useraddress].saveAmountFlag = false;
        }
    }

    function findLateUser() private{
      for (uint8 i = 0; i < groupSize; i++) {
          address useraddress = addressOrderList[i];
          if (users[useraddress].saveAmountFlag == false &&
          addressOrderList[turn - 1] != users[useraddress].userAddr
          ) {
              totalCashIn = totalCashIn - saveAmount;
              totalSaveAmount = totalSaveAmount + saveAmount;
                if(users[useraddress].latePayments==0){
                  cashOutUsers--;
              }
              users[useraddress].latePayments++;
              updateLatePayments();
          }
       }
    }

    function advanceTurn()
        public
        payable
        onlyAdmin(admin)
        atStage(Stages.Save)
    {
        require(startTime + turn*payTime + turn*withdrawTime < block.timestamp , "El usuario en turno aun puede retirar");
        if (
            totalSaveAmount < (groupSize-1) * saveAmount
            )
        {
          findLateUser();
        }

        address addressUserInTurn = addressOrderList[turn - 1];
        users[addressUserInTurn].userAddr.transfer(totalSaveAmount);
        totalSaveAmount = 0;
        if (turn >= groupSize) {
            stage = Stages.Finished;
        } else {
            newTurn();
        }
        turn++;
    }

    function withdrawCashIn()
        public
        payable
        atStage(Stages.Finished)
        onlyAdmin(admin)
    {
        //When all the rounds are done the admin sends the cash in to the users
        cashOut=totalCashIn/cashOutUsers;
        for (uint8 i = 0; i < groupSize; i++) {
            address useraddress = addressOrderList[i];
            if (users[useraddress].latePayments == 0) {
                users[useraddress].userAddr.transfer(cashOut);
            }
        }
    }

    function restartRound()
        public
        payable
        atStage(Stages.Finished)
        onlyAdmin(admin)
    {
        cashOut=totalCashIn/cashOutUsers;
        for(uint8 i = 0; i<groupSize; i++){
            address useraddress = addressOrderList[i];
            if(totalCashIn<cashIn*cashOutUsers){
                if (users[useraddress].latePayments == 0) {
                    users[useraddress].userAddr.transfer(cashOut);
                    totalCashIn=totalCashIn-cashOut;
                }
                users[useraddress].latePayments = 1;
                updateLatePayments();
            }
            users[useraddress].saveAmountFlag = false;
        }
        turn = 1;
        stage = Stages.Setup;
    }

    function payCashIn()
        public
        payable
        atStage(Stages.Setup)
        isRegisteredUser(users[msg.sender].currentRoundFlag)
    {       //Receive the comitment payment
        require(users[msg.sender].latePayments > 0, "Ya tenemos regisrado tu CashIn"); //you have payed the cash in
        require(msg.value == cashIn, 'Fondos Insuficientes');   //insufucuent funds
        totalCashIn = totalCashIn + msg.value;
        users[msg.sender].latePayments--;
        updateLatePayments();
        cashOutUsers++;
    }

    function updateLatePayments() private{
        for (uint8 i = 0; i<groupSize; i++){
            address updateAddress=addressOrderList[i];
            uint256 latePayment_=users[updateAddress].latePayments;
            latePaymentsList[i]=latePayment_;
        }
    }
}
