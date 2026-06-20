import { Hono } from 'hono';

import {
  checkHandler,
  LoginHandler,
  LogoutHandler,
  UpdateTokenHandler,
  GeneratePasskeyRegistrationOptionsHandler,
  VerifyPasskeyRegistrationHandler,
  GeneratePasskeyAuthenticationOptionsHandler,
  VerifyPasskeyAuthenticationHandler,
  Get2FAStatusHandler,
  Generate2FASecretHandler,
  Enable2FAHandler,
  Disable2FAHandler,
} from '@/napcat-webui-backend/src/api/Auth';

const router = new Hono();
router.post('/login', LoginHandler);
router.post('/check', checkHandler);
router.post('/logout', LogoutHandler);
router.post('/update_token', UpdateTokenHandler);
router.post('/passkey/generate-registration-options', GeneratePasskeyRegistrationOptionsHandler);
router.post('/passkey/verify-registration', VerifyPasskeyRegistrationHandler);
router.post('/passkey/generate-authentication-options', GeneratePasskeyAuthenticationOptionsHandler);
router.post('/passkey/verify-authentication', VerifyPasskeyAuthenticationHandler);
// router:获取2FA状态
router.get('/2fa/status', Get2FAStatusHandler);
// router:生成2FA密钥
router.post('/2fa/generate-secret', Generate2FASecretHandler);
// router:启用2FA
router.post('/2fa/enable', Enable2FAHandler);
// router:禁用2FA
router.post('/2fa/disable', Disable2FAHandler);

export { router as AuthRouter };
