// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

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
        uint8 userTurn;
        uint256 availableCashIn; //amount available in CashIn
        uint256 availableSavings;//Amount Available to withdraw
        uint256 amountPaid; //Amount paid by the user
        uint256 assingnedPayments; 
        uint256 unassignedPayments;
        uint8 latePayments; //late Payments incurred by the user
        uint256 owedTotalCashIn;
        bool isActive; //defines if the user is participating in the current round
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
    address[] public addressOrderList;
    uint256 public totalCashIn = 0;
    Stages public stage;

    //Time constants in seconds
    // Weekly by Default
    uint256 public payTime = 86400 * 7;
    


    constructor(
        uint256 _cashIn,
        uint256 _saveAmount,
        uint256 _groupSize,
        address payable _admin,
        uint256 _payTime) public {
        require(_admin != address(0), "La direccion del administrador no puede ser cero");
        require(_groupSize > 1 && _groupSize <= 10, "El tamanio del grupo debe ser mayor a uno y menor o igual a 10");
        admin = _admin;
        cashIn = _cashIn * 1e17; 
        saveAmount = _saveAmount * 1e17;
        groupSize = _groupSize;
        stage = Stages.Setup;
        addressOrderList = new address[](_groupSize);
        //latePaymentsList = new uint256[](_groupSize);
        require(_payTime > 0, "El tiempo para pagar no puede ser menor a un dia");
        payTime = _payTime;//86400 * _payTime;
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    function registerUser(uint8 _userTurn)
        external
        payable
        isPayAmountCorrect(msg.value, cashIn)
        atStage(Stages.Setup) {
        require(!users[msg.sender].isActive,"Ya estas registrado en esta ronda");    
        require(usersCounter < groupSize, "El grupo esta completo"); //the saving circle is full
        require(addressOrderList[_userTurn-1]==address(0), "Este lugar ya esta ocupado" );
        usersCounter++;
        users[msg.sender] = User(msg.sender, _userTurn, msg.value, 0, 0, 0, 0, 0, 0, true); //create user
        totalCashIn = totalCashIn + msg.value;
        addressOrderList[_userTurn-1]=msg.sender; //store user
    }




    function removeUser(uint256 _userTurn)
        external
        payable
        onlyAdmin(admin)
        atStage(Stages.Setup) {
        require(addressOrderList[_userTurn-1]!=address(0), "Este turno esta vacio");
        address removeAddress=addressOrderList[_userTurn-1];
        if(users[removeAddress].availableCashIn >0){
          //if user has cashIn available, send it back 
          uint256 availableCashInTemp = users[removeAddress].availableCashIn;
          users[removeAddress].availableCashIn = 0;
          totalCashIn = totalCashIn - availableCashInTemp;
          users[removeAddress].userAddr.transfer(availableCashInTemp);
        }
      addressOrderList[_userTurn-1]=address(0); //set address in turn to 0x00..
      usersCounter--;
      users[removeAddress].isActive = false;  // ¿tendría que poner turno en 0?
     
    }

    function startRound()
        external
        onlyAdmin(admin)
        atStage(Stages.Setup) {
        require(usersCounter == groupSize, "Aun hay lugares sin asignar");
        stage = Stages.Save;
        startTime= block.timestamp;
    }



    //Permite adelantar pagos o hacer abonos chiquitos
    //Primero se verifica si hay pagos pendientes al día y se abonan, si sobra se verifica si se debe algo al CashIn y se abona
    function addPayment() 
        external
        payable
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save) {
        //users make the payment for the cycle     
        require(msg.value <= futurePayments(), "You are paying more than the total saving amount");
        
        //First transaction that will complete saving of currentTurn and will trigger next turn 
        uint8 realTurn = getRealTurn();
        if (turn < realTurn){
            completeSavingsAndAdvanceTurn(); 
        }
        
        address userInTurn = addressOrderList[turn-1];
        
        //users[msg.sender].unassignedPayments = users[msg.sender].unassignedPayments + msg.value;
        uint256 deposit = msg.value;
        users[msg.sender].unassignedPayments+= deposit;
        
        uint256 obligation = obligationAtTime(msg.sender);
        uint256 debt = obligation - users[msg.sender].amountPaid;

        
        uint256 paymentToTurn;
        if (debt < deposit) {
            paymentToTurn = debt;
        } else {
            paymentToTurn = deposit;
        }
        
        //Si no he cubierto todos mis pagos hasta el día se asignan al usuario en turno.
        if (debt > 0){ 
            users[msg.sender].unassignedPayments = users[msg.sender].unassignedPayments - paymentToTurn;
            users[userInTurn].availableSavings = users[userInTurn].availableSavings + paymentToTurn;
            users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + paymentToTurn;
            users[msg.sender].amountPaid = users[msg.sender].amountPaid + paymentToTurn;
        }

        //Si tengo deuda en el cashIn. Si hay excedente se queda en saldo por asignar
        uint256 debtCashIn = cashIn - users[msg.sender].availableCashIn;
        if (debtCashIn > 0 && users[msg.sender].unassignedPayments > 0 ){
            //Si me alcanza para pagar toda la deuda del CashIn y me sobra
            if (debtCashIn <= users[msg.sender].unassignedPayments){
                users[msg.sender].unassignedPayments = users[msg.sender].unassignedPayments - debtCashIn;
                totalCashIn = totalCashIn + debtCashIn;
                users[msg.sender].availableCashIn = users[msg.sender].availableCashIn + debtCashIn;
                users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + debtCashIn;
            } else {  //Si no alcanzo a cubrir el pago completo del cash In
                uint256 paymentCashInTemp = users[msg.sender].unassignedPayments; //abono chiquito al cashIn
                users[msg.sender].unassignedPayments = 0;
                totalCashIn = totalCashIn + paymentCashInTemp;
                users[msg.sender].availableCashIn = users[msg.sender].availableCashIn + paymentCashInTemp;
                users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + paymentCashInTemp;
            }
        }

        if (realTurn > groupSize){
            endRosca();
        }


    }











    function withdrawTurn()   
        external
        payable
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save){  
        uint8 senderTurn = users[msg.sender].userTurn;
        uint8 realTurn = getRealTurn();
        require(realTurn > senderTurn, "Espera a llegar a tu turno");  //turn = turno actual de la rosca
        
        //First transaction that will complete saving of currentTurn and will trigger next turn 
        //Because this runs each user action, we are sure the user in turn has its availableSavings complete
        if (turn < realTurn){
            completeSavingsAndAdvanceTurn(); 
        }

        // Paga adeudos pendientes de availableSavings
        if (obligationAtTime(msg.sender) > users[msg.sender].amountPaid){
            payLateFromSavings();
        }
       
        uint256 savedAmountTemp = users[msg.sender].availableSavings;
        users[msg.sender].availableSavings = 0;
        users[msg.sender].userAddr.transfer(savedAmountTemp);
        savedAmountTemp=0;    
    }


    //Esta funcion se verifica que daba correr cada que se reliza un movimiento por parte de un usuario, 
    //solo correrá si es la primera vez que se corre en un turno, ya sea acción de retiro o pago.
    function completeSavingsAndAdvanceTurn() private atStage(Stages.Save) {
        
        for (uint8 i = 0; i < groupSize; i++) {
            address useraddress = addressOrderList[i];
            address userInTurn = addressOrderList[turn-1];
            uint256 debtUser =  obligationAtTime(useraddress) - users[useraddress].amountPaid;
            //Si el usuario debe
            if (debtUser>0){
                //Si el cashIn del usuario alcanza para pagar la deuda (1 o menos atrasado)
                if (users[useraddress].availableCashIn >= debtUser ){
                    users[useraddress].availableCashIn = users[useraddress].availableCashIn-debtUser; 
                    users[useraddress].amountPaid = users[useraddress].amountPaid + debtUser;
                    totalCashIn = totalCashIn - debtUser;
                    users[userInTurn].availableSavings = debtUser + users[userInTurn].availableSavings;
                    users[useraddress].owedTotalCashIn = users[useraddress].owedTotalCashIn + debtUser;

                    
                    
                }else{ //Si el cashIn no alcanza para pagar la deuda (+1 pago atrasado)(no hay cashIn)
                    uint256 tempCashIn = users[useraddress].availableCashIn; 
                    users[useraddress].availableCashIn = 0; // Se toma el CashIn
                    users[useraddress].amountPaid = users[useraddress].amountPaid + tempCashIn; //El monto que había en CashIn se usa para pagos
                    totalCashIn = totalCashIn - debtUser;  //tomo la deuda completa del TotalCashIn
                    users[useraddress].owedTotalCashIn =  users[useraddress].owedTotalCashIn + debtUser;
                    users[userInTurn].availableSavings = debtUser + users[userInTurn].availableSavings; 
                    users[useraddress].latePayments++; 

                }
                

            }
            

        }
        turn++;
        
                
    }


    function payLateFromSavings() private atStage(Stages.Save){
        users[msg.sender].availableSavings = users[msg.sender].availableSavings-users[msg.sender].owedTotalCashIn;
        totalCashIn = totalCashIn + users[msg.sender].owedTotalCashIn;
        users[msg.sender].owedTotalCashIn = 0;
        } 


    //Cuánto le falta por ahorrar total
    function futurePayments() public view returns (uint256) {
        uint256 totalSaving = (saveAmount*(groupSize-1));
        uint256 futurePayment = totalSaving - users[msg.sender].amountPaid;
        return futurePayment;
    }

    //Returns the total payment the user should have paid at the moment
    function obligationAtTime(address userAddress) public view returns (uint256) {
        uint256 expectedObligation;
        if (users[userAddress].userTurn <= turn){
            expectedObligation =  saveAmount * (turn-1);
        } else{
            expectedObligation =  saveAmount * (turn);
        }
        return expectedObligation;
    }

    function getRealTurn() public view atStage(Stages.Save) returns (uint8){
        
        uint8 realTurn = uint8((block.timestamp - startTime) / payTime)+1;
        return (realTurn);
    }

    function endRosca() private atStage(Sages.Save) {
        for (uint8 i = 0; i < groupSize; i++) {
            address userAddr = addressOrderList[i];
            uint256 amountTemp = users[userAddr].availableSavings + users[userAddr].availableCashIn; 
            users[userAddr].availableSavings = 0;
            users[userAddr].availableCashIn = 0;
            users[userAddr].userAddr.transfer(amountTemp);
            users[userAddr].isActive = false;
            amountTemp=0;            
        }

    } 


}




