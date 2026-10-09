import js from "@eslint/js";
import importPlugin from "eslint-plugin-import";
import globals from "globals";

export default [
    js.configs.recommended,
    importPlugin.flatConfigs.recommended,
    {
        languageOptions: {
            ecmaVersion: "latest",
            globals: globals.nodeBuiltin,
        },
        settings: {
            // The default Node resolver cannot resolve package exports such as csv-parse/sync.
            "import/resolver": { typescript: {} },
        },
        rules: {
            "import/order": "error",
        },
    },
];
