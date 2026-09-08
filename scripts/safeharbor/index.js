import "dotenv/config";
import { main } from "./src/cli.js";

process.exitCode = await main();
