export interface AppConfig {
  nodeEnv: string;
  port: number;
  database: {
    url: string;
    synchronize: boolean;
    logging: boolean;
  };
  jwt: {
    accessSecret: string;
    accessTtl: string;
    refreshSecret: string;
    refreshTtl: string;
  };
  cors: {
    origin: string;
  };
}

/**
 * Typed config factory consumed via ConfigService.get<T>('key'). Kept as a
 * single nested object (registered as the default namespace) so callers get
 * autocomplete instead of scattered `process.env` reads.
 */
export default (): AppConfig => ({
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: parseInt(process.env.PORT ?? '3000', 10),
  database: {
    url: process.env.DATABASE_URL ?? '',
    synchronize: process.env.DB_SYNCHRONIZE === 'true',
    logging: process.env.DB_LOGGING === 'true',
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? '',
    accessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? '',
    refreshTtl: process.env.JWT_REFRESH_TTL ?? '30d',
  },
  cors: {
    origin: process.env.CORS_ORIGIN ?? '*',
  },
});
