const { expectRevert } = require("@openzeppelin/test-helpers");
const Main = artifacts.require("Main");

contract("Main", async accounts => {
    it("should deploy Main contract correctly", async () => {
        const instance = await Main.deployed();
        expect(instance.address).to.not.equal(0)
    })

    it("should create a new round correctly", async () => {
        const instance = await Main.deployed();
        // uint _warranty, uint256 _saving, uint256 _groupSize, uint256 _payTime, IERC20 _token
        const result = await instance.createRound(1, 1, 4, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1");
        
        expect(result).to.have.a.property('receipt');
    })

    it("should return an error if the group size is greater than 10", async () => {
        const instance = await Main.deployed();
        const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 10";

        await expectRevert(
            instance.createRound(1, 1, 20, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
            errorMessage
        );
    })

    it("should return an error if the group size is less than 2", async () => {
        const instance = await Main.deployed();
        const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 10";

        await expectRevert(
            instance.createRound(1, 1, 0, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
            errorMessage
        )
    })

    it("should return an error if the payTime duration is less than a day", async () => {
        const instance = await Main.deployed();
        const errorMessage = "El tiempo para pagar no puede ser menor a un dia";

        await expectRevert(
            instance.createRound(1, 1, 3, 0, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
            errorMessage
        )
    })
})