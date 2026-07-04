module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'no-restricted-globals': ['error', 'name', 'length'],
    'prefer-arrow-callback': 'error',
    // Project uses single quotes throughout
    'quotes': ['error', 'single', {allowTemplateLiterals: true}],
    // Project uses spaces inside destructuring: { foo }
    'object-curly-spacing': ['error', 'always'],
    // JSDoc on every function is too noisy for a Cloud Functions backend
    'require-jsdoc': 'off',
    // 80 is too tight for modern JS
    'max-len': ['error', {code: 120, ignoreTemplateLiterals: true, ignoreStrings: true}],
    // 2-space indent, switch cases indented one level (not two)
    'indent': ['error', 2, {SwitchCase: 1}],
    // Allow ternary operators to break before ? and :
    'operator-linebreak': ['error', 'before'],
    // Trailing commas in multi-line contexts only
    'comma-dangle': ['error', 'always-multiline'],
    // No blank line padding inside blocks
    'padded-blocks': ['error', 'never'],
    // Require newline at end of file
    'eol-last': ['error', 'always'],
  },
  overrides: [
    {
      files: ['**/*.spec.*'],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
