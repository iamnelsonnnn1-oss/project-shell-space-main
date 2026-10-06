import Fastify from 'fastify';
import { unconfiguredAuth, unconfiguredOtp, unconfiguredVideo, unconfiguredKeys } from './interfaces/index.js';

/**
 * Build the Fastify app. Dependencies are injected so provider choices stay out of the core.
 * Product routes are added later; only the health endpoint and the error contract exist now.
 */
export function buildApp({ auth = unconfiguredAuth, otp = unconfiguredOtp, video = unconfiguredVideo, keys = unconfiguredKeys, logger = false } = {}) {
  const app = Fastify({ logger });
  app.decorate('providers', { auth, otp, video, keys });

  app.get('/api/health', async () => ({ status: 'ok' }));

  app.setErrorHandler((err, _req, reply) => {
    const status = err.statusCode ?? 500;
    reply.code(status).send({ error: status >= 500 && status !== 503 ? 'internal error' : err.message });
  });
  return app;
}
