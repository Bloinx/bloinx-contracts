const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const web3 = require("web3");
const Main = artifacts.require("Main");
const BlxToken = artifacts.require("BLXToken");
const cUSD = artifacts.require("TestERC20");

contract("Main", async (accounts) => {
  const adminFee = 10;
  let blxToken;
  let instance;
  let celoDollar;
  const [deployer, user1] = [accounts[0], accounts[1]];

  beforeEach(async () => {
    blxToken = await BlxToken.new("blxToken", "BLXT", 100, { from: deployer });
    instance = await Main.deployed();
    celoDollar = await cUSD.new();

    let role = web3.utils.asciiToHex("ADMIN_MINTER_ROLE");
    let newRole = role.replace("0x", "0x000000000000000000000000000000");

    await blxToken.grantRole(newRole, instance.address);
  });

  describe("Create Round", () => {
    it("should deploy Main contract correctly", async () => {
      expect(instance.address).to.not.equal(0);
    });

    it("should create a new round correctly", async () => {
      // uint _warranty, uint256 _saving, uint256 _groupSize, uint256 _adminFee, uint256 _payTime, IERC20 _token,address _blxaddr
      const result = await instance.createRound(
        5,
        5,
        4,
        adminFee,
        7,
        celoDollar.address,
        blxToken.address
      );

      expectEvent(result, "RoundCreated");
      expect(result).to.have.a.property("receipt");
    });

    it("should return an error if the group size is greater than 12", async () => {
      const errorMessage =
        "El tamanio del grupo debe ser mayor a uno y menor o igual a 12";

      await expectRevert(
        instance.createRound(
          5,
          5,
          20,
          adminFee,
          7,
          celoDollar.address,
          blxToken.address
        ),
        errorMessage
      );
    });

    it("should return an error if the group size is less than 2", async () => {
      const errorMessage =
        "El tamanio del grupo debe ser mayor a uno y menor o igual a 12";

      await expectRevert(
        instance.createRound(
          5,
          5,
          0,
          adminFee,
          7,
          celoDollar.address,
          blxToken.address
        ),
        errorMessage
      );
    });

    it("should return an error if the payTime duration is less than a week", async () => {
      const errorMessage = "El tiempo para pagar no puede ser menor a una semana";

      await expectRevert(
        instance.createRound(
          5,
          5,
          3,
          adminFee,
          6,
          celoDollar.address,
          blxToken.address
        ),
        errorMessage
      );
    });
  });

  describe("Set Dev Address", () => {
    it("should set new dev address", async () => {
      const newDevAddress = accounts[3];

      await instance.setDevFundAddress(newDevAddress, { from: deployer });
      const result = await instance.devFund();

      expect(result).to.equal(newDevAddress);
    });

    it("should fail if setDevAddress is not call by main owner", async () => {
      const newDevAddress = accounts[3];

      await expectRevert.unspecified(
        instance.setDevFundAddress(newDevAddress, { from: user1 })
      );
    });
  });

  describe("Set Fee", () => {
    it("should set new fee", async () => {
        const newFee = 10;
        await instance.setFee(newFee, { from: deployer });
        const fee = await instance.fee();
       
        expect(fee.toNumber()).to.equal(newFee);
    });

    it("should fail if setFee is not called by owner", async () => {
        const newFee = 10;

        await expectRevert.unspecified(
          instance.setFee(newFee, { from: user1 })
        );
    });
  })
});
