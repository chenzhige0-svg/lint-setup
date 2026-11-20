// ESLint 10 flat config —— JS / TS / JSX
//
// 直接使用（全局）：
//   eslint --config ~/.config/dev-toolbox/eslint.config.mjs .
// 项目内使用：复制为 eslint.config.mjs；优先用项目本地依赖，
// 找不到时回退到 ~/.config/dev-toolbox/node_modules（npm 全局软链）。
import { createRequire } from "node:module";

const localRequire = createRequire(import.meta.url);
const toolboxRequire = createRequire(
  `${process.env.HOME}/.config/dev-toolbox/eslint.config.mjs`,
);

function load(id) {
  try {
    return localRequire(id);
  } catch {
    return toolboxRequire(id);
  }
}

const js = load("@eslint/js");
const globals = load("globals");
const tseslint = load("typescript-eslint");

export default tseslint.config(
  {
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "**/build/**",
      "**/coverage/**",
      "**/.venv/**",
      "**/vendor/**",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.{js,mjs,cjs,jsx,ts,mts,cts,tsx}"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    rules: {
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/no-explicit-any": "warn",
      "no-console": "off",
      eqeqeq: ["error", "smart"],
    },
  },
  {
    files: ["**/*.js", "**/*.mjs", "**/*.cjs", "**/*.jsx"],
    ...tseslint.configs.disableTypeChecked,
  },
  {
    files: ["**/*.config.{js,mjs,cjs,ts}"],
    rules: { "no-undef": "off" },
  },
);
