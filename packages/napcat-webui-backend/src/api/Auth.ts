import type { Context } from 'hono';
import { AuthHelper } from '@/napcat-webui-backend/src/helper/SignToken';
import { PasskeyHelper } from '@/napcat-webui-backend/src/helper/PasskeyHelper';
import { TotpHelper } from '@/napcat-webui-backend/src/helper/TotpHelper';
import { WebUiDataRuntime } from '@/napcat-webui-backend/src/helper/Data';
import { sendSuccess, sendError } from '@/napcat-webui-backend/src/utils/response';
import { isEmpty } from '@/napcat-webui-backend/src/utils/check';
import { WebUiConfig, getInitialWebUiToken, setInitialWebUiToken } from '@/napcat-webui-backend/index';
import { getClientIP } from '@/napcat-webui-backend/src/middleware/cors';

// 登录 - 支持2FA验证
export const LoginHandler = async (c: Context) => {
  const WebUiConfigData = await WebUiConfig.GetWebUIConfig();
  const body = await c.req.json().catch(() => ({}));
  const bodyObj = body as Record<string, unknown>;
  const hash = bodyObj['hash'] as string | undefined;
  const totpCode = bodyObj['totpCode'] as string | undefined;
  const clientIP = getClientIP(c);

  if (isEmpty(hash)) {
    return sendError(c, 'token is empty');
  }
  if (!WebUiDataRuntime.checkLoginRate(clientIP, WebUiConfigData.loginRate)) {
    return sendError(c, 'login rate limit');
  }
  const initialToken = getInitialWebUiToken();
  if (!initialToken) {
    return sendError(c, 'Server token not initialized');
  }
  if (!AuthHelper.comparePasswordHash(initialToken, hash!)) {
    return sendError(c, 'token is invalid');
  }

  if (WebUiConfigData.enable2FA && WebUiConfigData.totpSecret) {
    if (!totpCode) {
      return sendSuccess(c, {
        require2FA: true,
        message: 'Please enter your authenticator code',
      });
    }

    if (!TotpHelper.verifyTotp(WebUiConfigData.totpSecret, totpCode)) {
      return sendError(c, 'Invalid or expired code');
    }

    const signCredential = Buffer.from(JSON.stringify(AuthHelper.signCredential(hash!))).toString('base64');
    return sendSuccess(c, {
      Credential: signCredential,
      require2FA: false,
    });
  }

  const signCredential = Buffer.from(JSON.stringify(AuthHelper.signCredential(hash!))).toString('base64');
  return sendSuccess(c, {
    Credential: signCredential,
  });
};

// 退出登录
export const LogoutHandler = async (c: Context) => {
  const authorization = c.req.header('authorization');
  try {
    const CredentialBase64 = authorization?.split(' ')[1] as string;
    const Credential = JSON.parse(Buffer.from(CredentialBase64, 'base64').toString());
    AuthHelper.revokeCredential(Credential);
    return sendSuccess(c, 'Logged out successfully');
  } catch (_e) {
    return sendError(c, 'Logout failed');
  }
};

// 检查登录状态
export const checkHandler = async (c: Context) => {
  const authorization = c.req.header('authorization');
  try {
    const CredentialBase64 = authorization?.split(' ')[1] as string;
    const Credential = JSON.parse(Buffer.from(CredentialBase64, 'base64').toString());

    if (AuthHelper.isCredentialRevoked(Credential)) {
      return sendError(c, 'Token has been revoked');
    }

    const initialToken = getInitialWebUiToken();
    if (!initialToken) {
      return sendError(c, 'Server token not initialized');
    }
    const valid = AuthHelper.validateCredentialWithinOneHour(initialToken, Credential);
    if (valid) return sendSuccess(c, null);
    return sendError(c, 'Authorization Failed');
  } catch (_e) {
    return sendError(c, 'Authorization Failed');
  }
};

// 修改密码（token）
export const UpdateTokenHandler = async (c: Context) => {
  const body = await c.req.json().catch(() => ({}));
  const bodyObj = body as Record<string, unknown>;
  const oldToken = bodyObj['oldToken'] as string | undefined;
  const newToken = bodyObj['newToken'] as string | undefined;
  const authorization = c.req.header('authorization');

  if (isEmpty(newToken)) {
    return sendError(c, 'newToken is empty');
  }

  if (isEmpty(oldToken)) {
    return sendError(c, 'oldToken is required');
  }

  if (oldToken === newToken) {
    return sendError(c, '新密码不能与旧密码相同');
  }

  if (newToken!.length < 6) {
    return sendError(c, '新密码至少需要6个字符');
  }

  if (!/[a-zA-Z]/.test(newToken!)) {
    return sendError(c, '新密码必须包含字母');
  }

  if (!/[0-9]/.test(newToken!)) {
    return sendError(c, '新密码必须包含数字');
  }

  try {
    if (authorization) {
      const CredentialBase64 = authorization.split(' ')[1] as string;
      const Credential = JSON.parse(Buffer.from(CredentialBase64, 'base64').toString());
      AuthHelper.revokeCredential(Credential);
    }

    const initialToken = getInitialWebUiToken();
    if (!initialToken) {
      return sendError(c, 'Server token not initialized');
    }
    if (initialToken !== oldToken) {
      return sendError(c, '旧 token 不匹配');
    }
    await WebUiConfig.UpdateWebUIConfig({ token: newToken! });
    setInitialWebUiToken(newToken!);

    return sendSuccess(c, 'Token updated successfully');
  } catch (e: any) {
    return sendError(c, 'Failed to update token: ' + e.message);
  }
};

// 生成Passkey注册选项
export const GeneratePasskeyRegistrationOptionsHandler = async (c: Context) => {
  try {
    const userId = 'napcat-user';
    const userName = 'NapCat User';

    const host = c.req.header('host') || 'localhost';
    const hostname = host.split(':')[0] || 'localhost';
    const rpId = (hostname === '127.0.0.1' || hostname === 'localhost') ? 'localhost' : hostname;

    const options = await PasskeyHelper.generateRegistrationOptions(userId, userName, rpId);
    return sendSuccess(c, options);
  } catch (error) {
    return sendError(c, 'Failed to generate registration options: ' + (error as Error).message);
  }
};

// 验证Passkey注册
export const VerifyPasskeyRegistrationHandler = async (c: Context) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const bodyObj = body as Record<string, unknown>;
    const resp = bodyObj['response'];
    if (!resp) {
      return sendError(c, 'Response is required');
    }

    const origin = c.req.header('origin') || (c.req.url.split('://')[0] + '://' + (c.req.header('host') || 'localhost'));
    const host = c.req.header('host') || 'localhost';
    const hostname = host.split(':')[0] || 'localhost';
    const rpId = (hostname === '127.0.0.1' || hostname === 'localhost') ? 'localhost' : hostname;
    const userId = 'napcat-user';
    const verification = await PasskeyHelper.verifyRegistration(userId, resp, origin, rpId);

    if (verification.verified) {
      return sendSuccess(c, { verified: true });
    } else {
      return sendError(c, 'Registration failed');
    }
  } catch (error) {
    return sendError(c, 'Registration verification failed: ' + (error as Error).message);
  }
};

// 生成Passkey认证选项
export const GeneratePasskeyAuthenticationOptionsHandler = async (c: Context) => {
  try {
    const userId = 'napcat-user';

    if (!(await PasskeyHelper.hasPasskeys(userId))) {
      return sendError(c, 'No passkeys registered');
    }

    const host = c.req.header('host') || 'localhost';
    const hostname = host.split(':')[0] || 'localhost';
    const rpId = (hostname === '127.0.0.1' || hostname === 'localhost') ? 'localhost' : hostname;

    const options = await PasskeyHelper.generateAuthenticationOptions(userId, rpId);
    return sendSuccess(c, options);
  } catch (error) {
    return sendError(c, 'Failed to generate authentication options: ' + (error as Error).message);
  }
};

// 验证Passkey认证
export const VerifyPasskeyAuthenticationHandler = async (c: Context) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const bodyObj = body as Record<string, unknown>;
    const resp = bodyObj['response'];
    if (!resp) {
      return sendError(c, 'Response is required');
    }

    const WebUiConfigData = await WebUiConfig.GetWebUIConfig();
    const clientIP = getClientIP(c);

    if (!WebUiDataRuntime.checkLoginRate(clientIP, WebUiConfigData.loginRate)) {
      return sendError(c, 'login rate limit');
    }

    const origin = c.req.header('origin') || (c.req.url.split('://')[0] + '://' + (c.req.header('host') || 'localhost'));
    const host = c.req.header('host') || 'localhost';
    const hostname = host.split(':')[0] || 'localhost';
    const rpId = (hostname === '127.0.0.1' || hostname === 'localhost') ? 'localhost' : hostname;
    const userId = 'napcat-user';
    const verification = await PasskeyHelper.verifyAuthentication(userId, resp, origin, rpId);

    if (verification.verified) {
      const initialToken = getInitialWebUiToken();
      if (!initialToken) {
        return sendError(c, 'Server token not initialized');
      }
      const signCredential = Buffer.from(JSON.stringify(AuthHelper.signCredential(AuthHelper.generatePasswordHash(initialToken)))).toString('base64');
      return sendSuccess(c, {
        Credential: signCredential,
      });
    } else {
      return sendError(c, 'Authentication failed');
    }
  } catch (error) {
    return sendError(c, 'Authentication verification failed: ' + (error as Error).message);
  }
};

// 获取2FA状态
export const Get2FAStatusHandler = async (c: Context) => {
  try {
    const WebUiConfigData = await WebUiConfig.GetWebUIConfig();
    return sendSuccess(c, {
      enable2FA: WebUiConfigData.enable2FA || false,
      hasSecret: !!WebUiConfigData.totpSecret,
    });
  } catch (error) {
    return sendError(c, '获取2FA状态失败: ' + (error as Error).message);
  }
};

// 生成2FA密钥
export const Generate2FASecretHandler = async (c: Context) => {
  try {
    const secret = TotpHelper.generateSecret();
    const qrCodeUrl = TotpHelper.generateQrCodeUrl(secret, 'NapCat WebUI', 'NapCat');

    return sendSuccess(c, {
      secret: secret,
      qrCodeUrl: qrCodeUrl,
    });
  } catch (error) {
    return sendError(c, 'Failed to generate 2FA secret: ' + (error as Error).message);
  }
};

// 启用2FA
export const Enable2FAHandler = async (c: Context) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const bodyObj = body as Record<string, unknown>;
    const secret = bodyObj['secret'] as string | undefined;
    const totpCode = bodyObj['totpCode'] as string | undefined;

    if (!secret || !totpCode) {
      return sendError(c, 'secret and totpCode are required');
    }

    if (!TotpHelper.verifyTotp(secret, totpCode)) {
      return sendError(c, 'Invalid code');
    }

    await WebUiConfig.UpdateWebUIConfig({
      enable2FA: true,
      totpSecret: secret,
    });

    return sendSuccess(c, { message: '2FA enabled' });
  } catch (error) {
    return sendError(c, 'Failed to enable 2FA: ' + (error as Error).message);
  }
};

// 禁用2FA - 需要验证当前TOTP代码
export const Disable2FAHandler = async (c: Context) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const bodyObj = body as Record<string, unknown>;
    const totpCode = bodyObj['totpCode'] as string | undefined;

    if (!totpCode) {
      return sendError(c, 'totpCode is required to disable 2FA');
    }

    const WebUiConfigData = await WebUiConfig.GetWebUIConfig();
    if (!WebUiConfigData.totpSecret) {
      return sendError(c, '2FA is not enabled');
    }

    if (!TotpHelper.verifyTotp(WebUiConfigData.totpSecret, totpCode)) {
      return sendError(c, 'Invalid code');
    }

    await WebUiConfig.UpdateWebUIConfig({
      enable2FA: false,
      totpSecret: '',
    });

    return sendSuccess(c, { message: '2FA disabled' });
  } catch (error) {
    return sendError(c, 'Failed to disable 2FA: ' + (error as Error).message);
  }
};