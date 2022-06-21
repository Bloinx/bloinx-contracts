const { expectRevert } = require("@openzeppelin/test-helpers");
const Main = artifacts.require("Main");

contract("Main", async accounts => {
    const adminFee = 10;
    let instance;

    beforeEach(async () => {
        instance = await Main.deployed();
    });

    describe("Create Round", () => {
        it("should deploy Main contract correctly", async () => {
            expect(instance.address).to.not.equal(0)
        })
    
        it("should create a new round correctly", async () => {
            // uint _warranty, uint256 _saving, uint256 _groupSize, uint256 _adminFee, uint256 _payTime, IERC20 _token
            const result = await instance.createRound(1, 1, 4, adminFee, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1");
            expect(result).to.have.a.property('receipt');
        })
    
        it("should return an error if the group size is greater than 10", async () => {
            const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 10";
    
            await expectRevert(
                instance.createRound(1, 1, 20, adminFee, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            );
        })
    
        it("should return an error if the group size is less than 2", async () => {
            const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 10";
    
            await expectRevert(
                instance.createRound(1, 1, 0, adminFee, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            )
        })
    
        it("should return an error if the payTime duration is less than a day", async () => {
            const errorMessage = "El tiempo para pagar no puede ser menor a un dia";
    
            await expectRevert(
                instance.createRound(1, 1, 3, adminFee, 0, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            )
        })
    });

    describe("Set Dev Address", () => {
        it("should set new dev address", async () => {
            const owner = await instance.owner()
            const newDevAddress = accounts[3];
            
            await instance.setDevAddress(newDevAddress, { from: owner });
            const result = await instance.devAddress();
            
            expect(result).to.equal(newDevAddress);
        })

        it("should fail if setDevAddress is not call by main owner", async () => {
            const errorMessage = "Ownable: caller is not the owner";
            const newDevAddress = accounts[3];
            
            await expectRevert(instance.setDevAddress(newDevAddress, { from: accounts[1] }), errorMessage);
        })
    })
   
})