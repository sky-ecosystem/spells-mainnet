import "dotenv/config";
import { runCommand } from "./src/cli.js";

process.exitCode = await runCommand(process.argv[2], {
    rpcUrl: process.env.ETH_RPC_URL,
    forkBlock: process.env.SAFEHARBOR_FORK_BLOCK,
    port: process.env.ANVIL_PORT,
});
