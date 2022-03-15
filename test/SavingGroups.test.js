const {
  expectRevert,
  time,
  constants,
  expectEvent,
} = require("@openzeppelin/test-helpers");
const web3 = require("web3");
const SavingGroups = artifacts.require("SavingGroups");
const TestERC20 = artifacts.require("TestERC20");

contract("SavingGroups", async (accounts) => {
  let tUSD;
  let contract;
  let savingGroups;
  const [celoDeployer, admin, user1, user2, user3] = [
    accounts[0],
    accounts[1],
    accounts[2],
    accounts[3],
    accounts[4],
  ];

  beforeEach(async () => {
    tUSD = await TestERC20.new({ from: celoDeployer });
    await tUSD.mint(celoDeployer, web3.utils.toWei('1000', 'ether'));
    await tUSD.transfer(admin, web3.utils.toWei('6', 'ether'));
    await tUSD.transfer(user1, web3.utils.toWei('6', 'ether'));
    await tUSD.transfer(user2, web3.utils.toWei('6', 'ether'));
    await tUSD.transfer(user3, web3.utils.toWei('6', 'ether'));
    // uint _warranty, uint256 _saving, uint256 _groupSize, address admin, uint256 _payTime, ERC20 _token
    savingGroups = await SavingGroups.new(1, 1, 3, admin, 180, (tUSD.address).toString());

    contract = savingGroups.address;
    await tUSD.approve(contract, web3.utils.toWei('100', 'ether'), { from: admin });
    await tUSD.approve(admin, web3.utils.toWei('6', 'ether'), { from: admin });
    await tUSD.approve(contract, web3.utils.toWei('100', 'ether'), { from: user1 });
    await tUSD.approve(user1, web3.utils.toWei('6', 'ether'), { from: user1 });
    await tUSD.approve(contract, web3.utils.toWei('100', 'ether'), { from: user2 });
    await tUSD.approve(user2, web3.utils.toWei('6', 'ether'), { from: user2 });
    await tUSD.approve(contract, web3.utils.toWei('100', 'ether'), { from: user3 });
    await tUSD.approve(user3, web3.utils.toWei('6', 'ether'), { from: user3 });

  });

  describe("Register User", () => {
    it("the users should be registered successfully", async () => {
      const adminRegister = await savingGroups.registerUser(1, { from: admin });
      
      expectEvent(adminRegister, "PayCashIn");
      expectEvent(adminRegister, "PayFee");
      expectEvent(adminRegister, "RegisterUser");
    });

    it("should return an error when the user try to register in a occupied turn", async () => {
      const errorMessage = "Este lugar ya esta ocupado";

      const adminRegister = await savingGroups.registerUser(1, { from: admin });
      const userOneRegister = await savingGroups.registerUser(2, { from: user1 });

      expectEvent(adminRegister, "RegisterUser");
      expectEvent(userOneRegister, "RegisterUser");

      await expectRevert(
        savingGroups.registerUser(2, { from: user2 }),
        errorMessage
      );
    });

    it("should return an error if the stage is different to Setup", async () => {
      const errorMessage = "Stage incorrecto para ejecutar la funcion";
     
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });
      await savingGroups.startRound({ from: admin });

      await expectRevert(
        savingGroups.registerUser(4, { from: user3 }),
        errorMessage
      );
    });

    it("should return an error if the group is complete", async () => {
      const errorMessage = "El grupo esta completo";

      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      await expectRevert(
        savingGroups.registerUser(4, { from: user3 }),
        errorMessage
      );
    });

    it("should return a total cashIn", async () => {
      const initialCashInBalance = await savingGroups.totalCashIn();
      expect(initialCashInBalance.toString()).equal('0');

      const cashInBN = await savingGroups.cashIn();
      const cashIn = web3.utils.fromWei(cashInBN, 'ether');
      const groupSize = await savingGroups.groupSize();

      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      const cashInExpected = groupSize * cashIn;
      const totalCashIn = await savingGroups.totalCashIn();
      
      expect(web3.utils.fromWei(totalCashIn, 'ether')).to.equal(cashInExpected.toString());
    });
  });

  describe("Remove User", () => {
    it("should remove user successfully", async () => {
      const turn = 3;
      const ZERO_ADDRESS = constants.ZERO_ADDRESS;

      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      const userRemoved = await savingGroups.removeUser(turn, { from: admin });
      expectEvent(userRemoved, "RemoveUser");

      const addressInRemovedTurn = await savingGroups.addressOrderList(turn-1);
      expect(addressInRemovedTurn).to.equal(ZERO_ADDRESS);
    });

    it("should return an error if the turn to remove is empty", async () => {
      const errorMessage = "Este turno esta vacio";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });

      await expectRevert(
        savingGroups.removeUser(3, { from: admin }),
        errorMessage
      );
    });

    it("should return an error if is not the admin calling the function", async () => {
      const errorMessage = "No tienes autorizacion para eliminar a este usuario";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      await expectRevert(
        savingGroups.removeUser(3, { from: user3 }),
        errorMessage
      );
    });

    it("should return an error if the admin try to remove their wallet", async () => {
      const errorMessage = "No puedes eliminar al administrador de la ronda";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      await expectRevert(
        savingGroups.removeUser(1, { from: admin }),
        errorMessage
      );
    });

    it("should can register another user after removed", async () => {
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      
      const userRemoved = await savingGroups.removeUser(2, { from: admin });
      expectEvent(userRemoved, "RemoveUser");

      const newRegister = await savingGroups.registerUser(2, {
        from: user3,
      });
      expectEvent(newRegister, "RegisterUser");
    });

    it("should return an error if the stage is different to Setup", async () => {
      const errorMessage = "Stage incorrecto para ejecutar la funcion";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });
      await savingGroups.startRound({ from: admin });

      await expectRevert(
        savingGroups.removeUser(3, { from: admin }),
        errorMessage
      );
    });
  });

  describe("Start Round", () => {
    it("should star round successfully", async () => {
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      const result = await savingGroups.startRound({ from: admin });
      expect(result).to.have.a.property("receipt");
    });

    it("should return an error if has a unassigned turns", async () => {
      const errorMessage =
        "Aun hay lugares sin asignar";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });

      await expectRevert(savingGroups.startRound({ from: admin }), errorMessage);
    });

    it("should return an error if is not the admin calling the function", async () => {
      const errorMessage = "Solo el admin puede llamar la funcion";
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });

      await expectRevert(savingGroups.startRound({from: user3}), errorMessage);
    });

    it("should return an error if the stage is different to Setup", async () => {
        const errorMessage = "Stage incorrecto para ejecutar la funcion";
        await savingGroups.registerUser(1, { from: admin });
        await savingGroups.registerUser(2, { from: user1 });
        await savingGroups.registerUser(3, { from: user2 });
        await savingGroups.startRound({ from: admin });
  
        await expectRevert(savingGroups.startRound({ from: admin }), errorMessage);
    });
  });

  describe("Add payment", () => {
    beforeEach(async () => {
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });
      await savingGroups.startRound({ from: admin });
    });

    it("should the users can deposit his pay", async () => {
      const contractInitialBalance = await tUSD.balanceOf(contract);
      const userOneDeposit = await savingGroups.addPayment(web3.utils.toWei('1', 'ether'), { from: user1 });
      const contractFinalBalance = await tUSD.balanceOf(contract);
      
      const initialBalance = web3.utils.fromWei(contractInitialBalance, 'ether');
      const finalBalance = web3.utils.fromWei(contractFinalBalance, 'ether');
      
      expectEvent(userOneDeposit, 'PayTurn');
      expect(+finalBalance).greaterThan(+initialBalance);
    });

    it("should fail if the user send an amount of zero", async () => {
      const errorMessage = "Pago incorrecto";
     
      await expectRevert(savingGroups.addPayment(web3.utils.toWei('0', 'ether'), { from: user1 }), errorMessage);
    });

    it("should the user must be registered to add payment", async () => {
      const errorMessage = "Usuario no registrado"; 
  
      await expectRevert(savingGroups.addPayment(web3.utils.toWei('2', 'ether'), { from: user3 }), errorMessage);
    });
  })

  describe("WithdrawFunds", () => {
    beforeEach(async () => {
      await savingGroups.registerUser(1, { from: admin });
      await savingGroups.registerUser(2, { from: user1 });
      await savingGroups.registerUser(3, { from: user2 });
      await savingGroups.startRound({ from: admin });

      await savingGroups.addPayment(web3.utils.toWei('1', 'ether'), { from: user1 });
      await savingGroups.addPayment(web3.utils.toWei('1', 'ether'), { from: user2 });
    });

    it("should the first turn of the round can withdraw his funds", async () => {
      const adminInitialBalance = await tUSD.balanceOf(admin);
      const availableSavings = await savingGroups.getUserAvailableSavings(1);
      
      await time.increase(550);
     
      const withdraw = await savingGroups.withdrawTurn({ from: admin });
      const adminFinalBalance = await tUSD.balanceOf(admin);
      const expectedBalance = Number(web3.utils.fromWei(adminInitialBalance, 'ether')) + Number(web3.utils.fromWei(availableSavings, 'ether'));
      
      expectEvent(withdraw, 'WithdrawFunds');
      expect(Number(web3.utils.fromWei(adminFinalBalance, 'ether'))).to.equal(expectedBalance);
    })
  })
  
});
