import "dotenv/config";
import { runCommand } from "./src/cli.js";
import { testSpell } from "./src/testSpell.js";

const command = process.argv[2];

if (command === "testSpell") {
    try {
        await testSpell({
            rpcUrl: process.env.ETH_RPC_URL,
            forkBlock: process.env.SAFEHARBOR_FORK_BLOCK,
            port: process.env.ANVIL_PORT,
        });
    } catch (error) {
        if (!error?.interrupted) {
            console.error(error instanceof Error ? error.message : error);
        }
        process.exitCode = error?.exitCode || 1;
    }
} else {
    process.exitCode = await runCommand(command, {
        rpcUrl: process.env.ETH_RPC_URL,
    });
}
