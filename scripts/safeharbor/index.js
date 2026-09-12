import "dotenv/config";
import { main } from "./src/cli/index.js";

process.exitCode = await main();
