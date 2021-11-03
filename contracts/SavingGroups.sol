// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4-solc-0.7/contracts/token/ERC20/IERC20.sol";
import "./Modifiers.sol";

contract SavingGroups is Modifiers {
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
        uint256 availableSavings; //Amount Available to withdraw
        uint256 amountPaid; //Amount paid by the user
        //uint256 assingnedPayments; //posiblemente se quita.
        uint256 unassignedPayments;
        uint8 latePayments; //late Payments incurred by the user
        uint256 owedTotalCashIn; // amount taken in credit from others cashIn
        bool isActive; //defines if the user is participating in the current round
    }

    mapping(address => User) public users;
    address payable public admin; //The user that deploy the contract is the administrator

    //Constructor deployment variables
    uint256 public cashIn; //amount to be payed as commitment at the begining of the saving circle
    uint256 public saveAmount; //Payment on each round/cycle
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
    uint256 public payTime = 86400;
    uint256 public feeCost = 0;
    address payable public constant devAddress =
        0xa7afB2cdf0b2C52cf03c438ec586B08443E500b4;
    IERC20 public cUSD; // 0x874069fa1eb16d44d622f2e0ca25eea172369bc1

    constructor(
        uint256 _cashIn,
        uint256 _saveAmount,
        uint256 _groupSize,
        address payable _admin,
        uint256 _payTime,
        IERC20 _token
    ) public {
        cUSD = _token;
        require(
            _admin != address(0),
            "La direccion del administrador no puede ser cero"
        );
        require(
            _groupSize > 1 && _groupSize <= 10,
            "El tamanio del grupo debe ser mayor a uno y menor o igual a 10"
        );
        admin = _admin;
        cashIn = _cashIn * 1e18;
        saveAmount = _saveAmount * 1e18;
        groupSize = _groupSize;
        stage = Stages.Setup;
        addressOrderList = new address[](_groupSize);
        require(
            _payTime > 0,
            "El tiempo para pagar no puede ser menor a un dia"
        );
        payTime = _payTime;//86400 * _payTime;
        feeCost = (saveAmount / 10000) * 500; // calculate 5% fee
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    function registerUser(uint8 _userTurn)
        external
        //payable
        // isPayAmountCorrect(msg.value, cashIn, feeCost)
        atStage(Stages.Setup)
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
        users[msg.sender] = User(msg.sender, _userTurn, cashIn, 0, 0, 0, 0, 0, true); //create user
        cUSD.transferFrom(msg.sender, address(this), cashIn);
        totalCashIn = totalCashIn + cashIn;
        //uint256 totalFee = cashIn - cashIn;
        //cUSD.transferFrom(msg.sender, devAddress, totalFee);
        cUSD.transferFrom(msg.sender, devAddress, feeCost);
        addressOrderList[_userTurn - 1] = msg.sender; //store user
    }

    function removeUser(uint256 _userTurn)
        external
        payable
        onlyAdmin(admin)
        atStage(Stages.Setup)
    {
        require(
            addressOrderList[_userTurn - 1] != address(0),
            "Este turno esta vacio"
        );
        address removeAddress = addressOrderList[_userTurn - 1];
        if (users[removeAddress].availableCashIn > 0) {
            //if user has cashIn available, send it back
            uint256 availableCashInTemp = users[removeAddress].availableCashIn;
            users[removeAddress].availableCashIn = 0;
            totalCashIn = totalCashIn - availableCashInTemp;
            // users[removeAddress].userAddr.transfer(availableCashInTemp);
            cUSD.transferFrom(
                address(this),
                users[removeAddress].userAddr,
                availableCashInTemp
            );
        }
        addressOrderList[_userTurn - 1] = address(0); //set address in turn to 0x00..
        usersCounter--;
        users[removeAddress].isActive = false; // ¿tendría que poner turno en 0?
    }

    function startRound() external onlyAdmin(admin) atStage(Stages.Setup) {
        require(usersCounter == groupSize, "Aun hay lugares sin asignar");
        stage = Stages.Save;
        startTime = block.timestamp;
    }

    //Permite adelantar pagos o hacer abonos chiquitos
    //Primero se verifica si hay pagos pendientes al día y se abonan, si sobra se verifica si se debe algo al CashIn y se abona
    function addPayment()
        external
        payable
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save)
    {
        //users make the payment for the cycle
        require(
            msg.value <= futurePayments(),
            "You are paying more than the total saving amount"
        );

        //First transaction that will complete saving of currentTurn and will trigger next turn
        uint8 realTurn = getRealTurn();
        if (turn < realTurn) {
            completeSavingsAndAdvanceTurn();
        }

        address userInTurn = addressOrderList[turn - 1];
        uint256 deposit = msg.value;
        users[msg.sender].unassignedPayments += deposit;

        //If userInTurn = msg.sender : se queda en unassigned

        uint256 obligation = obligationAtTime(msg.sender);
        uint256 debt;
        uint256 paymentToTurn;

        // PAGO DEUDA DEL TURNO CORRIENTE
        if (obligation <= users[msg.sender].amountPaid) {
            //no hay deuda del turno corriente
            debt = 0;
        } else {
            //hay deuda del turno corriente
            debt = obligation - users[msg.sender].amountPaid;

            if (userInTurn != msg.sender) {
                if (debt < deposit) {
                    paymentToTurn = debt;
                } else {
                    paymentToTurn = deposit;
                }

                //Si no he cubierto todos mis pagos hasta el día se asignan al usuario en turno.
                users[msg.sender].unassignedPayments =
                    users[msg.sender].unassignedPayments -
                    paymentToTurn;
                users[userInTurn].availableSavings =
                    users[userInTurn].availableSavings +
                    paymentToTurn;
                //users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + paymentToTurn;
                users[msg.sender].amountPaid =
                    users[msg.sender].amountPaid +
                    paymentToTurn;
            }
        }

        //PAGO DEUDA DEL CASHIN TOTAL

        if (
            users[msg.sender].owedTotalCashIn > 0 &&
            users[msg.sender].unassignedPayments > 0
        ) {
            uint256 paymentDebtOthers;
            if (
                users[msg.sender].owedTotalCashIn <=
                users[msg.sender].unassignedPayments
            ) {
                //unnasigned excede o iguala la deuda del cashIn
                paymentDebtOthers = users[msg.sender].owedTotalCashIn;
            } else {
                paymentDebtOthers = users[msg.sender].unassignedPayments; //cubre parcialmente la deuda del cashIn
            }

            users[msg.sender].unassignedPayments =
                users[msg.sender].unassignedPayments -
                paymentDebtOthers;
            totalCashIn = totalCashIn + paymentDebtOthers;
            //users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + paymentDebtOthers;
        }

        //Si tengo deuda en el cashIn. Si hay excedente se queda en saldo por asignar
        uint256 debtCashIn = cashIn - users[msg.sender].availableCashIn;
        if (debtCashIn > 0 && users[msg.sender].unassignedPayments > 0) {
            //Si me alcanza para pagar toda la deuda del CashIn y me sobra
            uint256 paymentCashInTemp;
            if (debtCashIn <= users[msg.sender].unassignedPayments) {
                //unnasigned excede o iguala la deuda del cashIn
                paymentCashInTemp = debtCashIn;
            } else {
                paymentCashInTemp = users[msg.sender].unassignedPayments; //cubre parcialmente la deuda del cashIn
            }

            users[msg.sender].unassignedPayments =
                users[msg.sender].unassignedPayments -
                paymentCashInTemp;
            totalCashIn = totalCashIn + paymentCashInTemp;
            users[msg.sender].availableCashIn =
                users[msg.sender].availableCashIn +
                paymentCashInTemp;
            //users[msg.sender].assingnedPayments = users[msg.sender].assingnedPayments + paymentCashInTemp;
        }
    }

    function withdrawTurn()
        external
        payable
        isRegisteredUser(users[msg.sender].isActive)
        atStage(Stages.Save)
    {
        uint8 senderTurn = users[msg.sender].userTurn;
        uint8 realTurn = getRealTurn();
        require(realTurn > senderTurn, "Espera a llegar a tu turno"); //turn = turno actual de la rosca

        //First transaction that will complete saving of currentTurn and will trigger next turn
        //Because this runs each user action, we are sure the user in turn has its availableSavings complete
        if (turn < realTurn) {
            completeSavingsAndAdvanceTurn();
        }

        // Paga adeudos pendientes de availableSavings
        if (obligationAtTime(msg.sender) > users[msg.sender].amountPaid) {
            payLateFromSavings();
        }

        uint256 savedAmountTemp = users[msg.sender].availableSavings;
        users[msg.sender].availableSavings = 0;
        users[msg.sender].userAddr.transfer(savedAmountTemp);
        savedAmountTemp = 0;
    }

    //Esta funcion se verifica que daba correr cada que se reliza un movimiento por parte de un usuario,
    //solo correrá si es la primera vez que se corre en un turno, ya sea acción de retiro o pago.
    function completeSavingsAndAdvanceTurn() private atStage(Stages.Save) {
        for (uint8 i = 0; i < groupSize; i++) {
            address useraddress = addressOrderList[i];
            address userInTurn = addressOrderList[turn - 1];
            uint256 obligation = obligationAtTime(useraddress);
            uint256 debtUser;

            if (useraddress != userInTurn) {
                //Assign unassignedPayments

                if (obligation > users[useraddress].amountPaid) {
                    //Si hay monto pendiente por cubrir el turno
                    debtUser = obligation - users[useraddress].amountPaid; //Monto pendiente por asignar
                } else {
                    debtUser = 0;
                }

                //Si el usuario debe
                if (debtUser > 0) {
                    //Asignamos pagos pendientes
                    if (users[useraddress].unassignedPayments > 0) {
                        uint256 toAssign;

                        if (debtUser < users[useraddress].unassignedPayments) {
                            //se paga toda la deuda y sigue con saldo a favor
                            toAssign = debtUser;
                        } else {
                            toAssign = users[useraddress].unassignedPayments;
                        }
                        users[useraddress].unassignedPayments =
                            users[useraddress].unassignedPayments -
                            toAssign;
                        users[useraddress].amountPaid =
                            users[useraddress].amountPaid +
                            toAssign;
                        users[userInTurn].availableCashIn =
                            users[userInTurn].availableSavings +
                            toAssign;
                        //users[useraddress].assingnedPayments = users[useraddress].assingnedPayments + toAssign;
                    }

                    //Recalculamos la deuda después de asingación
                    debtUser =
                        obligationAtTime(useraddress) -
                        users[useraddress].amountPaid;

                    // Si aún sigue habiendo deuda se paga del cashIn
                    if (debtUser > 0) {
                        users[useraddress].latePayments++; //Se marca deudor
                        uint256 tempCashIn;
                        //Si el cashIn del usuario alcanza para pagar la deuda (1 o menos atrasado)
                        if (users[useraddress].availableCashIn >= debtUser) {
                            tempCashIn = debtUser;
                        } else {
                            //más de 1 atrasado
                            tempCashIn = users[useraddress].availableCashIn;
                        }

                        users[useraddress].availableCashIn =
                            users[useraddress].availableCashIn -
                            tempCashIn;
                        users[useraddress].amountPaid =
                            users[useraddress].amountPaid +
                            tempCashIn;
                        totalCashIn = totalCashIn - debtUser;
                        users[userInTurn].availableSavings =
                            users[userInTurn].availableSavings +
                            debtUser;
                        users[useraddress].owedTotalCashIn =
                            users[useraddress].owedTotalCashIn +
                            debtUser; //Lo que se debe a la bolsa de CashIn
                    }
                }
            }
        }
        turn++;
    }

    function payLateFromSavings() internal atStage(Stages.Save) {
        //savings are complete at the time this function runs
        uint256 debtOwnCashIn = cashIn - users[msg.sender].availableCashIn;
        users[msg.sender].availableSavings =
            users[msg.sender].availableSavings -
            users[msg.sender].owedTotalCashIn -
            debtOwnCashIn;
        totalCashIn =
            totalCashIn +
            users[msg.sender].owedTotalCashIn +
            debtOwnCashIn;
        users[msg.sender].availableCashIn = cashIn;
        users[msg.sender].owedTotalCashIn = 0;
    }

    //Cuánto le falta por ahorrar total
    function futurePayments() public view returns (uint256) {
        uint256 totalSaving = (saveAmount * (groupSize - 1));
        uint256 futurePayment = totalSaving -
            users[msg.sender].amountPaid -
            users[msg.sender].unassignedPayments;
        return futurePayment;
    }

    //Returns the total payment the user should have paid at the moment
    function obligationAtTime(address userAddress)
        public
        view
        returns (uint256)
    {
        uint256 expectedObligation;
        if (users[userAddress].userTurn <= turn) {
            expectedObligation = saveAmount * (turn - 1);
        } else {
            expectedObligation = saveAmount * (turn);
        }
        return expectedObligation;
    }

    function getRealTurn() public view atStage(Stages.Save) returns (uint8) {
        uint8 realTurn = uint8((block.timestamp - startTime) / payTime) + 1;
        return (realTurn);
    }

    function endRound() public atStage(Stages.Save) {
        require(getRealTurn() > groupSize);

        uint256 sumAvailableCashIn = 0;
        for (uint8 i = 0; i < groupSize; i++) {
            address userAddr = addressOrderList[i];
            sumAvailableCashIn += users[userAddr].availableCashIn;
        }

        for (uint8 i = 0; i < groupSize; i++) {
            address userAddr = addressOrderList[i];
            uint256 realCashIn = users[userAddr].availableCashIn /
                sumAvailableCashIn;
            uint256 amountTemp = users[userAddr].availableSavings + realCashIn;
            users[userAddr].availableSavings = 0;
            users[userAddr].availableCashIn = 0;
            users[userAddr].userAddr.transfer(amountTemp);
            users[userAddr].isActive = false;
            amountTemp = 0;
        }
    }

    //Getters
    function getUserTurn(uint8 _userTurn) public view returns (uint8) {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].userTurn);
    }

    function getUserAvailableCashIn(uint8 _userTurn)
        public
        view
        returns (uint256)
    {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].availableCashIn);
    }

    function getUserAvailableSavings(uint8 _userTurn)
        public
        view
        returns (uint256)
    {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].availableSavings);
    }

    function getUserAmountPaid(uint8 _userTurn) public view returns (uint256) {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].amountPaid);
    }

    function getUserUnassignedPayments(uint8 _userTurn)
        public
        view
        returns (uint256)
    {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].unassignedPayments);
    }

    function getUserLatePayments(uint8 _userTurn) public view returns (uint8) {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].latePayments);
    }

    function getUserOwedTotalCashIn(uint8 _userTurn)
        public
        view
        returns (uint256)
    {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].owedTotalCashIn);
    }

    function getUserIsActive(uint8 _userTurn) public view returns (bool) {
        address userAddr = addressOrderList[_userTurn - 1];
        return (users[userAddr].isActive);
    }
}
