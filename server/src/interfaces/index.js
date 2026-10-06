// Provider boundaries. Concrete providers are pending Captain decisions, so the defaults below
// always fail closed. There is deliberately no plaintext or "allow all" fallback.
import { NotConfiguredError } from '../errors.js';

/**
 * @typedef {{ userId: string, email: string, fullName: string }} Identity
 *
 * @typedef {object} AuthProvider
 * @property {(request: { headers: Record<string, string | string[] | undefined> }) => Promise<Identity | null>} authenticate
 *   Resolve the caller. Return null when unauthenticated.
 *
 * @typedef {object} OtpProvider
 * @property {(email: string) => Promise<void>} send
 * @property {(email: string, code: string) => Promise<boolean>} verify
 *
 * @typedef {object} VideoProvider
 * @property {(args: { workspaceId: string, channelId: string, roomName: string }) => Promise<{ provider: string, joinUrl: string }>} createRoom
 *
 * @typedef {{ keyId: string, version: string }} KeyRef
 * @typedef {object} KeyProvider
 *   Key custody (GCP KMS is the decided custodian; the key and envelope model is not yet approved).
 * @property {(args: { workspaceId: string, plaintext: Uint8Array, aad: Uint8Array }) => Promise<{ ciphertext: Uint8Array, meta: Record<string, unknown> }>} encrypt
 * @property {(args: { workspaceId: string, ciphertext: Uint8Array, meta: Record<string, unknown>, aad: Uint8Array }) => Promise<Uint8Array>} decrypt
 */

const unconfigured = (name, methods) =>
  Object.fromEntries(methods.map((m) => [m, async () => { throw new NotConfiguredError(name); }]));

/** @type {AuthProvider} */
export const unconfiguredAuth = unconfigured('AuthProvider', ['authenticate']);
/** @type {OtpProvider} */
export const unconfiguredOtp = unconfigured('OtpProvider', ['send', 'verify']);
/** @type {VideoProvider} */
export const unconfiguredVideo = unconfigured('VideoProvider', ['createRoom']);
/** @type {KeyProvider} */
export const unconfiguredKeys = unconfigured('KeyProvider', ['encrypt', 'decrypt']);
