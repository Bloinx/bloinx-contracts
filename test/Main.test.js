const { expectRevert } = require("@openzeppelin/test-helpers");
const web3 = require("web3");
const Main = artifacts.require("Main");
const BlxToken = artifacts.require("BLXToken");

contract("Main", async accounts => {
    const adminFee = 10;
    let blxToken;
    let instance;
    const [deployer, user1] = [accounts[0], accounts[1]]

    beforeEach(async () => {
        blxToken = await BlxToken.new("blxToken", "BLXT", 100, { from: deployer });
        console.log("--->> ", blxToken.address);
        instance = await Main.deployed();
    });

    describe("Create Round", () => {
        it("should deploy Main contract correctly", async () => {
            expect(instance.address).to.not.equal(0)
        })
    
        it("should create a new round correctly", async () => {
            let role  = web3.utils.asciiToHex("ADMIN_MINTER_ROLE");
            console.log("Role --->> ", role);
            let newRole = role.replace('0x', '0x000000000000000000000000000000'); // web3.utils.hexToBytes(role);
            // console.log("New Role --->> ", newRole);
            const tokenResult =  await blxToken.grantRole(
                newRole, // 0x00000000000000000000000000000041444d494e5f4d494e5445525f524f4c45, //newRole,
                instance.address
            );
            //  const roleResult = await blxToken.getRoleAdmin(role, instance.address);
            //  console.log("TokenResult ", roleResult);
            // uint _warranty, uint256 _saving, uint256 _groupSize, uint256 _adminFee, uint256 _payTime, IERC20 _token,address _blxaddr
            const result = await instance.createRound(5, 5, 4, adminFee, 2, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1", blxToken.address);
            console.log(">>>> ", result);
            expect(result).to.have.a.property('receipt');
        })
    
        it.skip("should return an error if the group size is greater than 12", async () => {
            const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 12";
    
            await expectRevert(
                instance.createRound(5, 5, 20, adminFee, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1", "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            );
        })
    
        it.skip("should return an error if the group size is less than 2", async () => {
            const errorMessage = "El tamanio del grupo debe ser mayor a uno y menor o igual a 10";
    
            await expectRevert(
                instance.createRound(5, 5, 0, adminFee, 160, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1", "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            )
        })
    
        it.skip("should return an error if the payTime duration is less than a day", async () => {
            const errorMessage = "El tiempo para pagar no puede ser menor a un dia";
    
            await expectRevert(
                instance.createRound(5, 5, 3, adminFee, 0, "0x874069fa1eb16d44d622f2e0ca25eea172369bc1", "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"),
                errorMessage
            )
        })
    });

    describe.skip("Set Dev Address", () => {
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