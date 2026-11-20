// Stylelint 17 —— CSS / SCSS / Less
// 用法：stylelint --config ~/.config/dev-toolbox/stylelint.config.mjs "**/*.css"
export default {
  extends: ["stylelint-config-standard"],
  ignoreFiles: ["**/node_modules/**", "**/dist/**", "**/build/**", "**/coverage/**", "**/vendor/**"],
  rules: {
    // 允许 BEM / CSS Modules / Tailwind 风格命名
    "selector-class-pattern": null,
    "custom-property-pattern": null,
    "keyframes-name-pattern": null,
    // 现代项目常见写法
    "no-descending-specificity": null,
    "declaration-block-no-redundant-longhand-properties": null,
    "media-feature-range-notation": null,
  },
};
