/**
 * PR Build - 更新构建中状态评论
 *
 * 环境变量:
 * - GITHUB_TOKEN: GitHub API Token
 * - PR_NUMBER: PR 编号
 * - PR_SHA: PR 提交 SHA
 */

import { GitHubAPI, getEnv, getRepository } from './lib/github.ts';
import { generateBuildingComment, COMMENT_MARKER } from './lib/comment.ts';

const BUILD_TARGETS = ['NapCat.Framework', 'NapCat.Shell'];

async function main (): Promise<void> {
  console.log('🔨 Updating building status comment\n');

  const token = getEnv('GITHUB_TOKEN', true);
  const prNumber = parseInt(getEnv('PR_NUMBER', true), 10);
  const prSha = getEnv('PR_SHA', true);
  const { owner, repo } = getRepository();

  console.log(`PR: #${prNumber}`);
  console.log(`SHA: ${prSha}`);
  console.log(`Repo: ${owner}/${repo}\n`);

  const github = new GitHubAPI(token);
  const comment = generateBuildingComment(prSha, BUILD_TARGETS);

  await github.createOrUpdateComment(owner, repo, prNumber, comment, COMMENT_MARKER);
}

main().catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});
