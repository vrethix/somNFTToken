import { ethers } from "hardhat";
import { expect } from "chai";
import { TesNFT, TesNFT__factory } from "../typechain";
import { Signer } from "ethers";

describe("tesNFT token tests", () => {
    let tesNFT: TesNFT, tesNFTFactory: TesNFT__factory;
    let adminSigner: Signer, aliceSigner: Signer, bobSigner: Signer;
    let admin: string, alice: string, bob: string;
    before(async () => {
        tesNFTFactory = await ethers.getContractFactory("TesNFT");
        tesNFT = await tesNFTFactory.deploy();
    });
    beforeEach(async () => {
        [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
        admin = await adminSigner.getAddress();
        alice = await aliceSigner.getAddress();
        bob = await bobSigner.getAddress();
    });
    it("sets correct token name", async () => {
        expect(await tesNFT.name()).eq("Test NFT");
    });
    it("sets correct token symbol", async () => {
        expect(await tesNFT.symbol()).eq("TNT");
    });
    it("mints NFT", async () => {
        const ethAmount = "2";
            const weiAmount = ethers.utils.parseEther(ethAmount);
            const transaction = {
                value: weiAmount,
            };
        let tokenID = await tesNFT.Mint(alice,"",transaction);
        expect(await tesNFT.ownerOf(1)).eq(alice);
    });
    it("transfers to other address", async () => {
        const ethAmount = "2";
            const weiAmount = ethers.utils.parseEther(ethAmount);
            const transaction = {
                value: weiAmount,
            };
        let tokenID = await tesNFT.Mint(alice,"",transaction);
        await expect(tesNFT.connect(aliceSigner).transferFrom(alice,bob,1)).to.emit(tesNFT, "Transfer");
    });
    it("doesn't allow to transfer if not owner", async () => {
        await expect(tesNFT.connect(aliceSigner).transferFrom(alice,bob,1)).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    });
    it("doesn't allow to transferFrom if not minted", async () => {
        await expect(tesNFT.connect(aliceSigner).transferFrom(alice,bob,5)).to.be.revertedWith("ERC721: operator query for nonexistent token");
    });
});
