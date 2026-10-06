export class NotConfiguredError extends Error {
  constructor(provider) {
    super(`${provider} is not configured (pending Captain decision)`);
    this.name = 'NotConfiguredError';
    this.statusCode = 503;
    this.provider = provider;
  }
}
