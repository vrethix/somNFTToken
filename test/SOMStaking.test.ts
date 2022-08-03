import { ethers, network } from "hardhat";
import { expect } from "chai";
import {
    TestToken,
    TestToken__factory,
    Staking,
    Staking__factory,
} from "../typechain";
import { Signer, BigNumber } from "ethers";

const { parseEther } = ethers.utils;

describe("Staking tests", () => {
    let staking: Staking,
        stakingToken: TestToken,
        rewardToken: TestToken;
    let STAKING: Staking__factory,
        STAKING_TOKEN: TestToken__factory,
        REWARD_TOKEN: TestToken__factory;
    let adminSigner: Signer,
        aliceSigner: Signer,
        bobSigner: Signer,
        admin: string,
        alice: string,
        bob: string;
    let START_TIME: number;
    let REWARD_AMOUNT: BigNumber;
    let STOP_TIME: number; 
    let DURATION: number;
    let CAP = 0;

    before(async () => {
        STAKING_TOKEN = (await ethers.getContractFactory("TestToken")) as TestToken__factory;
        REWARD_TOKEN = (await ethers.getContractFactory("TestToken")) as TestToken__factory;
        STAKING = (await ethers.getContractFactory("Staking")) as Staking__factory;
    });

    beforeEach(async () => {
        REWARD_AMOUNT = parseEther("100"); // 100 tokens
        [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
        admin = await adminSigner.getAddress();
        alice = await aliceSigner.getAddress();
        bob = await bobSigner.getAddress();

        stakingToken = await STAKING_TOKEN.deploy();
        rewardToken = stakingToken;

        START_TIME = Date.now();
        STOP_TIME = START_TIME+ 3600;
        DURATION = STOP_TIME - START_TIME ;

        staking = await STAKING.deploy(
            stakingToken.address,
            rewardToken.address,
            REWARD_AMOUNT,
            START_TIME,
            STOP_TIME,
            CAP
        );
    });
    describe("Deployment tests", () => {
        it("deploys with correct params", async () => {
            expect(await staking.stakingToken()).eq(stakingToken.address);
            expect(await staking.rewardToken()).eq(rewardToken.address);
            expect(await staking.rewardAmount()).eq(parseEther("100"));
            expect(await staking.startTime()).eq(START_TIME);
            expect(await staking.stopTime()).eq(STOP_TIME);
            expect(await staking.rewardDuration()).eq(DURATION);
        });
        it("doesn't deploy with incorrect params", async () => {
            await expect(
                STAKING.deploy(admin, rewardToken.address, REWARD_AMOUNT, START_TIME, STOP_TIME, CAP)
            ).to.be.revertedWith("Staking: stakingToken not a contract address");
            await expect(
                STAKING.deploy(stakingToken.address, admin, REWARD_AMOUNT, START_TIME, STOP_TIME, CAP)
            ).to.be.revertedWith("Staking: rewardToken not a contract address");
            await expect(
                STAKING.deploy(stakingToken.address, rewardToken.address, 0, START_TIME, STOP_TIME, CAP)
            ).to.be.revertedWith("Staking: rewardAmount must be greater than zero");
            await expect(
                STAKING.deploy(
                    stakingToken.address,
                    rewardToken.address,
                    REWARD_AMOUNT,
                    now() + 20,
                    now() - 20,
                    CAP
                )
            ).to.be.revertedWith("Staking: incorrect timestamps");
            await expect(
                STAKING.deploy(
                    stakingToken.address,
                    rewardToken.address,
                    REWARD_AMOUNT,
                    now() - 20,
                    now() + 20,
                    CAP
                )
            ).to.be.revertedWith("Staking: incorrect timestamps");
        });
    });

    describe("Pre staking period tests", () => {
        it("doesn't allow staking before start time", async () => {
            await rewardToken.approve(staking.address, REWARD_AMOUNT);
            await staking.notifyRewardAmount();
            await expect(staking.stake(parseEther("10"))).to.be.revertedWith("Staking: staking not started");
        });
        it("`earned` fn returns 0 before staking start", async () => {
            expect(await staking.earned(admin)).eq(0);
        });
        it("`exit` fn throws if called before staking starts", async () => {
            await expect(staking.exit()).to.be.revertedWith("Staking: staking period not over yet");
        });
    });
    describe("Staking period tests", () => {
        beforeEach(async () => {
            await advanceTime(20);
            await rewardToken.approve(staking.address, REWARD_AMOUNT);
        });
        xit("doesn't allow to stake if reward tokens not pooled into the contract yet", async () => {
            await expect(staking.stake(parseEther("10"))).to.be.revertedWith(
                "Staking: Rewards not loaded into the contract yet"
            );
        });
        it("doesn't allow to stake without enough balance/approval of staking tokens", async () => {
            await staking.notifyRewardAmount();
            await stakingToken.transfer(alice, parseEther("10"));
            await expect(staking.connect(aliceSigner).stake(parseEther("10"))).to.be.revertedWith(
                "ERC20: transfer amount exceeds allowance"
            );
            await stakingToken.connect(aliceSigner).approve(staking.address, parseEther("20"));
            await expect(staking.connect(aliceSigner).stake(parseEther("20"))).to.be.revertedWith(
                "ERC20: transfer amount exceeds balance"
            );
        });
        it("allows only admin to pause", async () => {
            await expect(staking.connect(aliceSigner).pause()).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
            await expect(staking.pause()).to.emit(staking, "Paused").withArgs(admin);
        });
        it("allows only owner to set CAP", async () => {
            await expect(staking.connect(bobSigner).setCap(parseEther("20000000"))).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
            await expect(await staking.setCap(parseEther("20000000")))
                .to.emit(staking, "CapChange")
                .withArgs(parseEther("10000000"), parseEther("20000000"));
        });

        describe("Staking tests", () => {
            beforeEach(async () => {
                await staking.notifyRewardAmount();
                await stakingToken.transfer(alice, parseEther("10000000"));
                await stakingToken.transfer(bob, parseEther("10000000"));
                await stakingToken.approve(staking.address, ethers.constants.MaxUint256);
                await stakingToken.connect(aliceSigner).approve(staking.address, ethers.constants.MaxUint256);
                await stakingToken.connect(bobSigner).approve(staking.address, ethers.constants.MaxUint256);
            });
            it("allows alice to stake", async () => {
                const stakingTokenBalance = await stakingToken.balanceOf(alice);
                await staking.connect(aliceSigner).stake(parseEther("10"));
                expect(await stakingToken.balanceOf(alice)).eq(stakingTokenBalance.sub(parseEther("10")));
            });
            it("doesn't allow to set CAP below total staked", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await expect(staking.setCap(parseEther("9"))).to.be.revertedWith(
                    "Staking: new cap less than already staked amount"
                );
            });
            it("allows alice and bob to stake", async () => {
                await staking.connect(aliceSigner).stake(parseEther("600"));
                await staking.connect(bobSigner).stake(parseEther("10"));
            });
            it("doesn't allow to stake more than CAP", async () => {
                await staking.connect(aliceSigner).stake(parseEther("5000000"));
                await expect(staking.connect(bobSigner).stake(parseEther("5000001"))).to.be.revertedWith(
                    "Staking: over cap limit"
                );
                await staking.connect(bobSigner).stake(parseEther("5000000"));
                await expect(staking.stake("1")).to.be.revertedWith("Staking: over cap limit");
            });
            it("reward check, case: alice stakes at the beginning", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(1800);
                expect(await staking.earned(alice))
                    .gt(parseEther("49"))
                    .lt(parseEther("51"));
                await advanceTime(1800);
                expect(await staking.earned(alice)).gt(parseEther("99"));
            });
            it("reward check, case: bob joins in halfway", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(1800);
                await staking.connect(bobSigner).stake(parseEther("10"));
                await advanceTime(1800);
                expect(await staking.earned(alice))
                    .gt(parseEther("74"))
                    .lt(parseEther("76"));
                expect(await staking.earned(bob))
                    .gt(parseEther("24"))
                    .lt(parseEther("26"));
            });
            it("reward check, case: admin stakes mid firsthalf, alice at mid, bob at mid secondhalf", async () => {
                await advanceTime(900);
                await staking.stake(parseEther("10"));
                await advanceTime(900);
                await staking.connect(aliceSigner).stake(parseEther("20"));
                await advanceTime(900);
                await staking.connect(bobSigner).stake(parseEther("30"));
                await advanceTime(900);
                expect(await staking.earned(admin))
                    .gt(parseEther("37"))
                    .lt(parseEther("38"));
                expect(await staking.earned(alice))
                    .gt(parseEther("24"))
                    .lt(parseEther("25"));
                expect(await staking.earned(bob))
                    .gt(parseEther("12"))
                    .lt(parseEther("13"));
            });

            it("throws when attempting to stake if paused", async () => {
                await staking.pause();
                await expect(staking.connect(aliceSigner).stake(parseEther("10"))).to.be.revertedWith(
                    "Pausable: paused"
                );
            });
            it("throws when attempting to withdraw when paused", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(3600);
                await staking.pause();
                await expect(staking.connect(aliceSigner).exit()).to.be.revertedWith("Pausable: paused");
            });
            it("withdraws reward", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(1800);
                await staking.connect(bobSigner).stake(parseEther("10"));
                await advanceTime(1800);
                const aliceStakingTokenBalance = await stakingToken.balanceOf(alice);
                const bobStakingTokenBalance = await stakingToken.balanceOf(bob);
                const aliceRewardTokenBalance = await rewardToken.balanceOf(alice);
                const bobRewardTokenBalance = await rewardToken.balanceOf(bob);
                await staking.connect(aliceSigner).exit();
                await staking.connect(bobSigner).exit();
                // expect(await stakingToken.balanceOf(alice)).eq(aliceStakingTokenBalance.add(parseEther("10")))
                // expect(await stakingToken.balanceOf(bob)).eq(bobStakingTokenBalance.add(parseEther("10")))
                expect(await rewardToken.balanceOf(alice)).gt(aliceRewardTokenBalance.add(parseEther("74")));
                expect(await rewardToken.balanceOf(bob)).gt(bobRewardTokenBalance.add(parseEther("24")));
            });

            it("throws on withdraw before stopTime", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(1800);
                await expect(staking.connect(aliceSigner).exit()).to.be.revertedWith(
                    "Staking: staking period not over"
                );
            });

            it("doesn't allow to withdraw if didn't participate in staking", async () => {
                await advanceTime(3600);
                await expect(staking.connect(aliceSigner).exit()).to.be.revertedWith(
                    "Staking: cannot withdraw 0"
                );
            });
            it("doesn't allow to rewithdraw", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(3600);
                await staking.connect(aliceSigner).exit();
                await expect(staking.connect(aliceSigner).exit()).to.be.revertedWith(
                    "Staking: cannot withdraw 0"
                );
            });
            it("`earned` returns 0 when already withdrawn", async () => {
                await staking.connect(aliceSigner).stake(parseEther("10"));
                await advanceTime(3600);
                await staking.connect(aliceSigner).exit();
                expect(await staking.earned(alice)).eq(0);
            });
        });
    });
});

/**
 * Advance block timestamp
 */
async function advanceTime(seconds: number) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

function now() {
    return Math.round(Date.now() / 1000);
}
