import "dotenv/config";
import { runCommand } from "./src/cli.js";

process.exitCode = await runCommand(process.argv[2]);
