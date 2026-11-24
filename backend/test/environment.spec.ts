import { validateConfig } from '../src/config/environment';
describe('environment', () => {
  const valid = {
    DATABASE_URL: 'postgresql://user:pass@localhost:5432/est',
    JWT_SECRET: 'a'.repeat(40),
    CORS_ORIGINS: 'http://localhost:8080',
    PUBLIC_BASE_URL: 'http://localhost:3000',
  };
  it('uses secure token defaults', () => {
    expect(validateConfig(valid).accessTtl).toBe(900);
  });
  it('rejects short secrets', () => {
    expect(() => validateConfig({ ...valid, JWT_SECRET: 'short' })).toThrow();
  });
  it('rejects wildcard origins', () => {
    expect(() => validateConfig({ ...valid, CORS_ORIGINS: '*' })).toThrow();
  });
  it('rejects partial Firebase credentials', () => {
    expect(() =>
      validateConfig({ ...valid, FIREBASE_PROJECT_ID: 'project' }),
    ).toThrow();
  });
});
