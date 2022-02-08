const {
  expectRevert,
  time,
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
    // it("should remove user successfully", async () => {
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });

    //   const userRemoved = await savingGroups.removeUser(3, { from: admin });
    //   expectEvent(userRemoved, "RemoveUser");
    // });

    // it("should return an error if the turn to remove is empty", async () => {
    //   const errorMessage = "Este turno esta vacio";
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });

    //   await expectRevert(
    //     savingGroups.removeUser(3, { from: admin }),
    //     errorMessage
    //   );
    // });

    // it("should can register another user after removed", async () => {
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });

    //   const userRemoved = await savingGroups.removeUser(3, { from: admin });
    //   expectEvent(userRemoved, "RemoveUser");

    //   const newRegister = await savingGroups.registerUser(3, {
    //     from: user3,
    //     value: 1 * 10 ** 18,
    //   });
    //   expectEvent(newRegister, "RegisterUser");
    // });

    // it("should return an error if is not the admin calling the function", async () => {
    //   const errorMessage = "Solo el admin puede llamar la funcion";
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });

    //   await expectRevert(
    //     savingGroups.removeUser(3, { from: user3 }),
    //     errorMessage
    //   );
    // });

    // it("should return an error if the stage is different to Setup", async () => {
    //   const errorMessage = "Stage incorrecto para ejecutar la funcion";
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });
    //   await savingGroups.startRound();

    //   await expectRevert(
    //     savingGroups.removeUser(3, { from: admin }),
    //     errorMessage
    //   );
    // });
  });

  describe("Start Round", () => {
    // it("should star round successfully", async () => {
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });

    //   const result = await savingGroups.startRound();
    //   expect(result).to.have.a.property("receipt");
    // });

    // it("should return an error if has a unassigned turns", async () => {
    //   const errorMessage =
    //     "Aun hay lugares sin asignar o alguien no ha pagado la garantia";
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });

    //   await expectRevert(savingGroups.startRound(), errorMessage);
    // });

    // it("should return an error if is not the admin calling the function", async () => {
    //   const errorMessage = "Solo el admin puede llamar la funcion";
    //   await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //   await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });

    //   await expectRevert(savingGroups.startRound({from: user3}), errorMessage);
    // });

    // it("should return an error if the stage is different to Setup", async () => {
    //     const errorMessage = "Stage incorrecto para ejecutar la funcion";
    //     await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 18 });
    //     await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 18 });
    //     await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 18 });
    //     await savingGroups.startRound();
  
    //     await expectRevert(savingGroups.startRound(), errorMessage);
    // });
  });

  // describe('Pay Turn', () => {
  //     it("should the users can deposit his pay", async () => {
  //       await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 17 });
  //       await savingGroups.startRound();

  //       const userOneDeposit = await savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17 });
  //       const userTwoDeposit = await savingGroups.payTurn({ from: user2, value: 1 * 10 ** 17 });
  //       const totalSaveAmount = await savingGroups.totalSaveAmount();
        
  //       expectEvent(userOneDeposit, 'PayTurn');
  //       expectEvent(userTwoDeposit, 'PayTurn');
  //       expect(totalSaveAmount.toString()).to.equal((2 * 10 ** 17).toString());
  //     });

  //     it("should if the user already pay his turn avoid depositing again", async () => {
  //       const errorMessage = "Ya ahorraste este turno"; 
  //       await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 17 });
  //       await savingGroups.startRound();

  //       const userOneDeposit = await savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17 });
  //       expectEvent(userOneDeposit, 'PayTurn');

  //      await expectRevert(savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17}), errorMessage);
  //     });

  //     it("should the user must be registered to pay turn", async () => {
  //       const errorMessage = "Usuario no registrado"; 
  //       await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 17 });
  //       await savingGroups.startRound();

  //       const userOneDeposit = await savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17 });
  //       expectEvent(userOneDeposit, 'PayTurn');

  //      await expectRevert(savingGroups.payTurn({ from: user3, value: 1 * 10 ** 17}), errorMessage);
  //     });

  //     it("should return an error if the pay amount is incorrect", async () => {
  //       const errorMessage = "Monto incorrecto"; 
  //       await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 17 });
  //       await savingGroups.startRound();

  //       const userOneDeposit = await savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17 });
  //       expectEvent(userOneDeposit, 'PayTurn');

  //      await expectRevert(savingGroups.payTurn({ from: user2, value: 3 * 10 ** 17}), errorMessage);
  //     });

  //     it("should return an error if is not the user turn to pay", async () => {
  //       const errorMessage = "En este turno no depositas"; 
  //       await savingGroups.registerUser(1, { from: admin, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(2, { from: user1, value: 1 * 10 ** 17 });
  //       await savingGroups.registerUser(3, { from: user2, value: 1 * 10 ** 17 });
  //       await savingGroups.startRound();

  //       const userOneDeposit = await savingGroups.payTurn({ from: user1, value: 1 * 10 ** 17 });
  //       expectEvent(userOneDeposit, 'PayTurn');

  //      await expectRevert(savingGroups.payTurn({ from: admin, value: 1 * 10 ** 17}), errorMessage);
  //     });
  // })
  
});
