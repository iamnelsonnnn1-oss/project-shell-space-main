import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  // Loopback only: nginx (fed by Cloudflare Tunnel) is the sole entry point.
  HOST: z.literal('127.0.0.1').default('127.0.0.1'),
  PORT: z.coerce.number().int().min(1024).max(65535).default(3000),
  DATABASE_URL: z.string().url(),
});

export function loadConfig(env = process.env) {
  return schema.parse(env);
}
