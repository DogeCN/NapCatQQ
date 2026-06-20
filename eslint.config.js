import neostandard from 'neostandard';

/** 尾随逗号 */
const commaDangle = val => {
  if (val?.rules?.['@stylistic/comma-dangle']?.[0] === 'warn') {
    const rule = val?.rules?.['@stylistic/comma-dangle']?.[1];
    Object.keys(rule).forEach(key => {
      rule[key] = 'always-multiline';
    });
    val.rules['@stylistic/comma-dangle'][1] = rule;
  }

  /** 三元表达式 */
  if (val?.rules?.['@stylistic/indent']) {
    val.rules['@stylistic/indent'][2] = {
      ...val.rules?.['@stylistic/indent']?.[2],
      flatTernaryExpressions: true,
      offsetTernaryExpressions: false,
    };
  }

  /** 支持下划线 - 禁用 camelcase 规则 */
  if (val?.rules?.camelcase) {
    val.rules.camelcase = 'off';
  }

  /** 未使用的变量强制报错 */
  if (val?.rules?.['@typescript-eslint/no-unused-vars']) {
    val.rules['@typescript-eslint/no-unused-vars'] = ['error', {
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
      caughtErrorsIgnorePattern: '^_',
    }];
  }

  /** 放宽 stylistic 规则 - 降为 warning */
  const stylisticRelaxRules = [
    '@stylistic/eol-last',
    '@stylistic/quotes',
    '@stylistic/quote-props',
    '@stylistic/object-property-newline',
    '@stylistic/space-before-function-paren',
    '@stylistic/spaced-comment',
    '@stylistic/multiline-ternary',
  ];
  for (const key of stylisticRelaxRules) {
    if (val?.rules?.[key]) {
      val.rules[key] = 'warn';
    }
  }

  /** 放宽其他非核心逻辑的规则 */
  const relaxRules = [
    'no-undef-init',
    'no-control-regex',
    'one-var',
    'no-unneeded-ternary',
    'no-void',
    'object-shorthand',
    'import-x/no-duplicates',
    'react/jsx-no-comment-textnodes',
  ];
  for (const key of relaxRules) {
    if (val?.rules?.[key]) {
      val.rules[key] = 'warn';
    }
  }

  return val;
};

/** 忽略的文件 */
const ignores = [
  'node_modules',
  '**/dist/**',
  'launcher',
];

const options = neostandard({
  ts: true,
  ignores,
  semi: true, // 强制使用分号
}).map(commaDangle);

export default options;