// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Modifiers.sol";
import "./BLXToken.sol";

contract SavingGroups is Modifiers {
    enum Stages {
        //Stages of the round
        Setup,
        Save,
        Finished,
        Emergency
    }

    struct User {
        //Information from each user
        address userAddr;
        uint8 userTurn;
        uint256 availableCashIn; //amount available in CashIn
        uint256 availableSavings;//Amount Available to withdraw
        uint256 assignedPayments; //Assigned either by payment or debt
        uint256 unassignedPayments;
        uint8 latePayments; //late Payments incurred by the user
        uint256 owedTotalCashIn; // amount taken in credit from others cashIn
        bool isActive; //defines if the user is participating in the current round
        uint256 withdrewAmount;
    }

    mapping(address => User) public users;
    address public admin; //The user that deploy the contract is the administrator

    //Constructor deployment variables
    uint256 public cashIn; //amount to be payed as commitment at the begining of the saving circle
    uint256 public saveAmount; //Payment on each round/cycle
    uint256 public groupSize; //Number of slots for users to participate on the saving circle
    uint256 public adminFee; //The fee the admin will charge to the users, it will be taken from the users cashin
    address public devFund; // fees will be sent here

    //Counters and flags
    uint256 usersCounter = 0;
    uint8 public turn = 1; //Current cycle/round in the saving circle
    uint256 public startTime;
    address[] public addressOrderList;
    uint256 public totalCashIn = 0;
    Stages public stage;
    bool public outOfFunds = false;

    //Time constants in seconds
    // Weekly by Default
    uint256 public payTime = 0;
    uint256 public fee = 0;
    uint256 public feeCost = 0;
    ERC20 public stableToken; // USDC Polygon Muimbai 0x0FA8781a83E46826621b3BC094Ea2A0212e71B23
    BLXToken public BLX;

    // BloinxEvents
    event RoundCreated(uint256 indexed saveAmount, uint256 indexed groupSize);
    event RegisterUser(address indexed user, uint8 indexed turn);
    event PayCashIn(address indexed user, bool indexed success);
    event PayFee(address indexed user, bool indexed success);
    event RemoveUser(address indexed removedBy, address indexed user, uint8 indexed turn);
    event PayTurn(address indexed user, bool indexed success);
    event LatePayment(address indexed user, uint8 indexed turn);
    event WithdrawFunds(address indexed user, uint256 indexed amount, bool indexed success);
    event EndRound(address indexed roundAddress, uint256 indexed startAt, uint256 indexed endAt);
    event EmergencyWithdraw(address indexed roundAddress, uint256 indexed funds);

    constructor(
        uint256 _cashIn,
        uint256 _saveAmount,
        uint256 _groupSize,
        address _admin,
        uint256 _adminFee,
        uint256 _payTime,
        ERC20 _token,
        BLXToken _BLX,
        address _devFund,
        uint256 _fee
    ) public {
        stableToken = _token;
        require(_admin != address(0), "La direccion del administrador no puede ser cero");
        require(_groupSize > 1 && _groupSize <= 12, "El tamanio del grupo debe ser mayor a uno y menor o igual a 12");
        require(_cashIn >= 2, "El deposito de seguridad debe ser minimo de 2 USD");
        require(_saveAmount >= 2, "El pago debe ser minimo de 2 USD");
        require(_adminFee<= 100);
        admin = _admin;
        adminFee = _adminFee;
        groupSize = _groupSize;
        devFund = _devFund;
        BLX = _BLX;
        cashIn = _cashIn * 10 ** stableToken.decimals();
        saveAmount = _saveAmount * 10 ** stableToken.decimals();
        stage = Stages.Setup;
        addressOrderList = new address[](_groupSize);
        require(_payTime > 0, "El tiempo para pagar no puede ser menor a un dia");
        payTime = _payTime * 60; //86400;
        feeCost = (saveAmount * 100 * _fee)/ 10000; // calculate 5% fee
        emit RoundCreated(saveAmount, groupSize);
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage, "Stage incorrecto para ejecutar la funcion");
        _;
    }

    function registerUser(uint8 _userTurn)
    external atStage(Stages.Setup)
    {
        require(
            !users[msg.sender].isActive,
            "Ya estas registrado en esta ronda"
        );
        require(usersCounter < groupSize, "El grupo esta completo"); //the saving circle is full
        require(
            addressOrderList[_userTurn - 1] == address(0),
            "Este lugar ya esta ocupado"
        );
        usersCounter++;
        users[msg.sender] = User(msg.sender, _userTurn, cashIn, 0, 0, 0, 0, 0, true, 0); //create user
        (bool registerSuccess) = transferFrom(address(this), cashIn);
        emit PayCashIn(msg.sender, registerSuccess);
        (bool payFeeSuccess) = transferFrom(devFund, feeCost);
        emit PayFee(msg.sender, payFeeSuccess);
        totalCashIn += cashIn;
        addressOrderList[_userTurn-1]=msg.sender; //store user
        emit RegisterUser(msg.sender, _userTurn);
    }

    function removeUser(uint8 _userTurn)
        external
        atStage(Stages.Setup) {
        require(msg.sender == admin || msg.sender == addressOrderList[_userTurn-1],
					"No tienes autorizacion para eliminar a este usuario"
				);
        require(addressOrderList[_userTurn-1]!=address(0),
					"Este turno esta vacio"
				);
				require(admin != addressOrderList[_userTurn-1],
					"No puedes eliminar al administrador de la ronda"
				);
        address removeAddress=addressOrderList[_userTurn-1];
        if(users[removeAddress].availableCashIn >0){
          //if user has cashIn available, send it back
          uint256 availableCashInTemp = users[removeAddress].availableCashIn;
          users[removeAddress].availableCashIn = 0;
          totalCashIn = totalCashIn - availableCashInTemp;
          transferTo(users[removeAddress].userAddr, availableCashInTemp);
        }
      addressOrderList[_userTurn-1]= address(0); //set address in turn to 0x00..
      usersCounter --;
      users[removeAddress].isActive = false;  // ¿tendría que poner turno en 0?
      emit RemoveUser(msg.sender, removeAddress, _userTurn);
    }

    function startRound() external onlyAdmin(admin) atStage(Stages.Setup) {
        require(usersCounter == groupSize, "Aun hay lugares sin asignar");
        stage = Stages.Save;
        startTime = block.timestamp;
    }

    //Permite adelantar pagos o hacer abonos chiquitos
    /*
		Primero se verifica si hay pagos pendientes al día
		y se abonan, si sobra se verifica si se debe algo al CashIn y se abona
		*/
    function addPayment(uint256 _payAmount)
        external
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save) {
        //users make the payment for the cycle
        require(_payAmount <= futurePayments() && _payAmount > 0 , "Pago incorrecto");

        //First transaction that will complete saving of currentTurn and will trigger next turn
        uint8 realTurn = getRealTurn();
        if (turn < realTurn){
            completeSavingsAndAdvanceTurn(turn);
        }

        address userInTurn = addressOrderList[turn-1];
        uint256 deposit = _payAmount;
        users[msg.sender].unassignedPayments+= deposit;

        uint256 obligation = obligationAtTime(msg.sender);
        uint256 debtToTurn;
        uint256 paymentToTurn;

        //Detecting place to assign

        //checking debt in current turn:

        if (obligation <= users[msg.sender].assignedPayments){  //no hay deuda del turno corriente
            debtToTurn = 0;
        } else {  //hay deuda del turno corriente
            debtToTurn = obligation - users[msg.sender].assignedPayments;

        //checking debt in Total CashIn: (owedTotalCashIn)

        //PAYMENTS: first: current turn debt, then totalCashIn

            if (userInTurn != msg.sender) {
                if (debtToTurn < deposit) {
                    paymentToTurn = debtToTurn;
                } else {
                    paymentToTurn = deposit;
                }

                //Si no he cubierto todos mis pagos hasta el día se asignan al usuario en turno.
                users[msg.sender].unassignedPayments -= paymentToTurn;
                users[userInTurn].availableSavings += paymentToTurn;
                users[msg.sender].assignedPayments +=  paymentToTurn;
            }
        }

        //PAGO DEUDA DEL CASHIN TOTAL
        if (users[msg.sender].owedTotalCashIn > 0 && users[msg.sender].unassignedPayments > 0 ){
            uint256 paymentTotalCashIn;
						//unnasigned excede o iguala la deuda del cashIn
            if (users[msg.sender].owedTotalCashIn <= users[msg.sender].unassignedPayments) {
                paymentTotalCashIn = users[msg.sender].owedTotalCashIn;
            } else {
                paymentTotalCashIn = users[msg.sender].unassignedPayments;  //cubre parcialmente la deuda del cashIn
            }

            users[msg.sender].unassignedPayments -= paymentTotalCashIn;
            totalCashIn = totalCashIn + paymentTotalCashIn;
            users[msg.sender].owedTotalCashIn -= paymentTotalCashIn;
        }

        //update my own availableCashIn
        if (users[msg.sender].owedTotalCashIn < cashIn){
            users[msg.sender].availableCashIn = cashIn - users[msg.sender].owedTotalCashIn;
        } else{
            users[msg.sender].availableCashIn = 0;
        }
        (bool success) = transferFrom(address(this), _payAmount);
        emit PayTurn(msg.sender, success);
    }

    function withdrawTurn()
        external
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save)
    {
        uint8 senderTurn = users[msg.sender].userTurn;

        uint8 realTurn = getRealTurn();
        require(realTurn > senderTurn, "Espera a llegar a tu turno"); //turn = turno actual de la rosca
        require(users[msg.sender].withdrewAmount == 0 );
        //First transaction that will complete saving of currentTurn and will trigger next turn
        //Because this runs each user action, we are sure the user in turn has its availableSavings complete
        if (turn < realTurn){
            completeSavingsAndAdvanceTurn(turn);
        }

        // Paga adeudos pendientes de availableSavings
        if (obligationAtTime(msg.sender) > users[msg.sender].assignedPayments){
            payLateFromSavings(msg.sender);
        }

        uint256 savedAmountTemp = 0;
        savedAmountTemp = users[msg.sender].availableSavings;
        users[msg.sender].availableSavings = 0;
        users[msg.sender].withdrewAmount += savedAmountTemp;
        (bool success) = transferTo(users[msg.sender].userAddr, savedAmountTemp);
        emit WithdrawFunds(users[msg.sender].userAddr, savedAmountTemp, success);
        if (outOfFunds){
            stage = Stages.Emergency;
        }
    }

    function transferFrom(address _to, uint256 _payAmount) internal returns (bool) {
      bool success = stableToken.transferFrom(msg.sender, _to, _payAmount);
      return success;
    }

    function transferTo(address _to, uint256 _amount) internal returns (bool) {
      bool success = stableToken.transfer(_to, _amount);
      return success;
    }
    //Esta funcion se verifica que daba correr cada que se reliza un movimiento por parte de un usuario,
    //solo correrá si es la primera vez que se corre en un turno, ya sea acción de retiro o pago.
    function completeSavingsAndAdvanceTurn(uint8 turno) private {
        address userInTurn = addressOrderList[turno-1];
        for (uint8 i = 0; i < groupSize; i++) {
            address useraddress = addressOrderList[i]; // 3
            uint256 obligation = obligationAtTime(useraddress);
            uint256 debtUser;

            if(useraddress != userInTurn){

                //Assign unassignedPayments
                if (obligation > users[useraddress].assignedPayments){  //Si hay monto pendiente por cubrir el turno
                    debtUser = obligation - users[useraddress].assignedPayments; //Monto pendiente por asignar
                } else {
                    debtUser = 0;
                }
                //Si el usuario debe
                if (debtUser>0){
                    //Asignamos pagos pendientes
                    if (users[useraddress].unassignedPayments > 0) {
                        uint256 toAssign;
												//se paga toda la deuda y sigue con saldo a favor
                        if (debtUser < users[useraddress].unassignedPayments) {
                            toAssign = debtUser;
                        } else {
                            toAssign = users[useraddress].unassignedPayments;
                        }
                        users[useraddress].unassignedPayments = users[useraddress].unassignedPayments - toAssign;
                        users[useraddress].assignedPayments = users[useraddress].assignedPayments + toAssign;
                        users[userInTurn].availableSavings = users[userInTurn].availableSavings + toAssign;
                        //Recalculamos la deuda después de asingación para pagar con deuda
                        debtUser =  obligationAtTime(useraddress) - users[useraddress].assignedPayments;
                    }

                    // Si aún sigue habiendo deuda se paga del cashIn
                    if (debtUser > 0) {
                        users[useraddress].latePayments++; //Se marca deudor
                        emit LatePayment(users[msg.sender].userAddr, turn);
                        if (totalCashIn >= debtUser) {
                            totalCashIn -= debtUser;
                            users[useraddress].assignedPayments += debtUser;
                            users[useraddress].owedTotalCashIn += debtUser;  //Lo que se debe a la bolsa de CashIn
                            users[userInTurn].availableSavings += debtUser;

                        } else {   //se traban los fondos
                            outOfFunds = true;
                        }
                        //update my own availableCashIn
                        if (users[useraddress].owedTotalCashIn < cashIn){
                            users[useraddress].availableCashIn = cashIn - users[useraddress].owedTotalCashIn;
                        } else {
                            users[useraddress].availableCashIn = 0;
                        }

                    }
                }
            }
        }
        turn++;
    }

    function payLateFromSavings(address _userAddress) internal {
        if (users[_userAddress].availableSavings >= users[_userAddress].owedTotalCashIn){
            users[_userAddress].availableSavings -= users[_userAddress].owedTotalCashIn;
            totalCashIn += users[_userAddress].owedTotalCashIn;
            users[_userAddress].availableCashIn = cashIn;
            users[_userAddress].owedTotalCashIn = 0;
        }
        else{
            outOfFunds = true;
        }

    }

    function emergencyWithdraw() public atStage(Stages.Emergency) {
        require (stableToken.balanceOf(address(this)) > 0, "No hay saldo por retirar");
        for (uint8 turno = turn; turno <= groupSize; turno++) {
            completeSavingsAndAdvanceTurn(turno);
        }
        uint256 saldoAtorado = stableToken.balanceOf(address(this));
        for (uint8 i = 0; i < groupSize; i++) {
                address userAddr = addressOrderList[i];
                payLateFromSavings(userAddr);
                if (users[userAddr].withdrewAmount == 0 && saldoAtorado > 0){
                    if (users[userAddr].availableSavings <= saldoAtorado){
                        transferTo(users[userAddr].userAddr, users[userAddr].availableSavings);
                        saldoAtorado -= users[userAddr].availableSavings;
                    }
                    else{
                        transferTo(users[userAddr].userAddr, saldoAtorado);
                    }
                }
        }
        if (saldoAtorado > 0){
            transferTo(devFund, saldoAtorado);
        }
        emit EmergencyWithdraw(address(this), saldoAtorado);
    }

    function endRound() public atStage(Stages.Save) {
        require(getRealTurn() > groupSize, "No ha terminado la ronda");
        for (uint8 turno = turn; turno <= groupSize; turno++) {
            completeSavingsAndAdvanceTurn(turno);
        }

        uint256 sumAvailableCashIn = 0;
        for (uint8 i = 0; i < groupSize; i++) {
            address userAddr = addressOrderList[i];
            if(users[userAddr].availableSavings >= users[userAddr].owedTotalCashIn){
                payLateFromSavings(userAddr);
            }
            sumAvailableCashIn += users[userAddr].availableCashIn;
        }
        if(!outOfFunds) {
            uint256 totalAdminFee = 0;
            uint256 amountDevFund = 0;
            for (uint8 i = 0; i < groupSize; i++) {
                address userAddr = addressOrderList[i];
                uint256 cashInReturn = ((users[userAddr].availableCashIn * totalCashIn)/sumAvailableCashIn);
                users[userAddr].availableCashIn = 0;
                users[userAddr].isActive = false;
                uint256 amountTempAdmin=(cashInReturn*adminFee)/100;
                totalAdminFee += amountTempAdmin;
                uint256 amountTempUsr = cashInReturn - amountTempAdmin + users[userAddr].availableSavings;
                users[userAddr].availableSavings = 0;
                transferTo(users[userAddr].userAddr, amountTempUsr);
                uint256 reward = (10 * cashInReturn * users[userAddr].userTurn * users[userAddr].userTurn);
                //BLX.mint(users[userAddr].userAddr, reward);
                amountDevFund += reward/10;
                cashInReturn = 0;
                reward = 0;
                emit EndRound(address(this), startTime, block.timestamp);
            }
            transferTo(admin, totalAdminFee);
            //BLX.mint(devFund, amountDevFund);
            stage = Stages.Finished;
        } else {
          for (uint8 i = 0; i < groupSize; i++) {
                address userAddr = addressOrderList[i];
                uint256 amountTemp = users[userAddr].availableSavings + ((users[userAddr].availableCashIn * totalCashIn)/sumAvailableCashIn);
                users[userAddr].availableSavings = 0;
                users[userAddr].availableCashIn = 0;
                users[userAddr].isActive = false;
                amountTemp = 0;
            }
            stage = Stages.Emergency;
        }

    }

    //Getters
    //Cuánto le falta por ahorrar total
    function futurePayments() public view returns (uint256) {
			uint256 totalSaving = (saveAmount*(groupSize-1));
			uint256 futurePayment = totalSaving - users[msg.sender].assignedPayments - users[msg.sender].unassignedPayments + users[msg.sender].owedTotalCashIn;
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

    function getUserAvailableCashIn(uint8 _userTurn) public view returns (uint256){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].availableCashIn);
    }

    function getUserAvailableSavings(uint8 _userTurn) public view returns (uint256){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].availableSavings);
    }

    function getUserAmountPaid(uint8 _userTurn) public view returns (uint256){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].assignedPayments);
    }

    function getUserUnassignedPayments(uint8 _userTurn) public view returns (uint256){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].unassignedPayments);
    }

    function getUserLatePayments(uint8 _userTurn) public view returns (uint8){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].latePayments);
    }

    function getUserOwedTotalCashIn(uint8 _userTurn) public view returns (uint256){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].owedTotalCashIn);
    }

    function getUserIsActive(uint8 _userTurn) public view returns (bool){
			address userAddr = addressOrderList[_userTurn-1];
			return(users[userAddr].isActive);
    }
}
