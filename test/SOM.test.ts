import { ethers } from "hardhat";
import { expect } from "chai";
import { SoulsOfMeta, SoulsOfMeta__factory } from "../typechain";
import { Signer } from "ethers";

describe("soulsOfMeta token tests", () => {
    let soulsOfMeta: SoulsOfMeta, soulsOfMetaFactory: SoulsOfMeta__factory;
    let adminSigner: Signer, aliceSigner: Signer, bobSigner: Signer;
    let admin: string, alice: string, bob: string;
    before(async () => {
        soulsOfMetaFactory = await ethers.getContractFactory("SoulsOfMeta");
        soulsOfMeta = await soulsOfMetaFactory.deploy("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
    });
    beforeEach(async () => {
        [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
        admin = await adminSigner.getAddress();
        alice = await aliceSigner.getAddress();
        bob = await bobSigner.getAddress();
    });
    it("sets correct token name", async () => {
        expect(await soulsOfMeta.name()).eq("Souls Of Meta");
    });
    it("sets correct token symbol", async () => {
        expect(await soulsOfMeta.symbol()).eq("SOM");
    });
    it("sets correct token decimals", async () => {
        expect(await soulsOfMeta.decimals()).eq(9);
    });
    it("mints on deployment", async () => {
        console.log("30", (await soulsOfMeta.balanceOf(admin)).toString())

        expect(await soulsOfMeta.balanceOf(admin)).eq(ethers.utils.parseEther("3000000"));
    });
    it("transfers to other address", async () => {
        await expect(soulsOfMeta.transfer(alice, 1000)).to.emit(soulsOfMeta, "Transfer").withArgs(admin, alice, 1000);
    });
    it("doesn't allow to transfer if insufficient balance", async () => {
        await expect(soulsOfMeta.connect(aliceSigner).transfer(bob, 1001)).to.be.reverted;
    });
    it("doesn't allow transferring to 0 address", async () => {
        await expect(soulsOfMeta.transfer(ethers.constants.AddressZero, 1000)).to.be.reverted;
    });
    it("sets correct allowance", async () => {
        await soulsOfMeta.approve(alice, 1000);
        expect(await soulsOfMeta.allowance(admin, alice)).eq(1000);
    });
    it("allows to transferFrom", async () => {
        await soulsOfMeta.approve(alice, 1000);
        await soulsOfMeta.connect(aliceSigner).transferFrom(admin, bob, 1000);
        expect(await soulsOfMeta.balanceOf(bob)).eq(1000);
    });
    it("doesn't allow to transferFrom if insufficient allowance", async () => {
        await soulsOfMeta.approve(alice, 1000);
        await expect(soulsOfMeta.connect(aliceSigner).transferFrom(admin, bob, 1001)).to.be.reverted;
    });
});
