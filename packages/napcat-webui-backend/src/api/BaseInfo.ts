import type { Context } from 'hono';
import { WebUiDataRuntime } from '@/napcat-webui-backend/src/helper/Data';

import { sendSuccess, sendError } from '@/napcat-webui-backend/src/utils/response';
import { WebUiConfig, webUiPathWrapper } from '@/napcat-webui-backend/index';
// 更新检查已移除：不再访问上游 GitHub（getLatestTag/getAllReleases 直接返回本地数据）
import { getMirrorConfig } from '@/napcat-common/src/mirror';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

export const GetNapCatVersion = (c: Context) => {
  const data = WebUiDataRuntime.GetNapCatVersion();
  return sendSuccess(c, { version: data });
};

// 不再检查上游更新：直接返回当前本地版本，避免外网请求与 500 报错
export const getLatestTagHandler = async (c: Context) => {
  return sendSuccess(c, WebUiDataRuntime.GetNapCatVersion());
};

/**
 * 版本信息接口
 */
export interface VersionInfo {
  tag: string;
  type: 'release' | 'prerelease' | 'action';
  /** Action artifact 专用字段 */
  artifactId?: number;
  artifactName?: string;
  createdAt?: string;
  expiresAt?: string;
  size?: number;
  workflowRunId?: number;
  headSha?: string;
  workflowTitle?: string;
}

// 不再检查上游：返回空版本列表，更新功能不可用但不报错
export const getAllReleasesHandler = async (c: Context) => {
  return sendSuccess(c, {
    versions: [],
    pagination: { page: 1, pageSize: 20, total: 0, totalPages: 0 },
    mirror: '',
  });
};

export const QQVersionHandler = (c: Context) => {
  const data = WebUiDataRuntime.getQQVersion();
  return sendSuccess(c, data);
};

export const GetThemeConfigHandler = async (c: Context) => {
  const data = await WebUiConfig.GetTheme();
  return sendSuccess(c, data);
};

export const SetThemeConfigHandler = async (c: Context) => {
  const body = await c.req.json().catch(() => ({}));
  const { theme } = body as { theme?: unknown };
  if (theme === undefined || theme === null || typeof theme !== 'object') {
    return sendError(c, 'theme is required and must be an object');
  }
  await WebUiConfig.UpdateTheme(theme as Parameters<typeof WebUiConfig.UpdateTheme>[0]);
  return sendSuccess(c, { message: '更新成功' });
};

export const GetMirrorsHandler = (c: Context) => {
  const config = getMirrorConfig();
  return sendSuccess(c, { mirrors: config.fileMirrors });
};

export const GetNapCatFileHashHandler = (c: Context) => {
  try {
    const filePath = path.join(webUiPathWrapper.binaryPath, 'napcat.mjs');
    const fileBuffer = fs.readFileSync(filePath);
    const hash = crypto.createHash('sha512').update(fileBuffer).digest('hex');
    return sendSuccess(c, { hash, file: 'napcat.mjs', algorithm: 'sha512' });
  } catch (error) {
    return sendError(c, `无法计算 napcat.mjs 的 hash：${(error as Error).message}`);
  }
};
