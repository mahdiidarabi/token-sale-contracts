import { expect, use } from "chai"
import { deployments, ethers } from "hardhat"
import { Signer, BigNumber, BigNumberish } from "ethers"
import { deployMockContract,MockContract } from "@ethereum-waffle/mock-contract";
import { Address } from "hardhat-deploy/dist/types";
import { solidity, MockProvider } from "ethereum-waffle"
import { exitCode } from "process";
import exp from "constants";

const {
    advanceBlockWithTime,
    takeSnapshot,
    revertProvider,
} = require("./utils");

use(solidity)

describe("AtlantisTokenSale", async () => {
  it("check the address used as native token", async () => {
    console.log("fsfsdsd")
  })
})

