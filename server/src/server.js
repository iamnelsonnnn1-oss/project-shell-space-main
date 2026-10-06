import pg from 'pg';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
// The pool must use the non-owner shellspace_app role so row-level security applies.
export const pool = new pg.Pool({ connectionString: config.DATABASE_URL, max: 5 });
const app = buildApp({ logger: true });
await app.listen({ host: config.HOST, port: config.PORT });
