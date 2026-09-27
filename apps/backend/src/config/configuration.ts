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
  mail: {
    resendApiKey: string;
    fromName: string;
    fromEmail: string;
  };
  sms: {
    renflairApiKey: string;
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
  mail: {
    resendApiKey: process.env.RESEND_API_KEY ?? '',
    fromName: process.env.MAIL_FROM_NAME ?? 'Cricket League',
    // onboarding@resend.dev is Resend's built-in sandbox sender, usable
    // with no domain verification — but Resend then only allows sending TO
    // the account's own signup address until a domain is verified. Once
    // itsdigitalindia.co.in is verified in Resend, set MAIL_FROM_EMAIL to
    // an address on that domain to send to any recipient.
    fromEmail: process.env.MAIL_FROM_EMAIL ?? 'onboarding@resend.dev',
  },
  sms: {
    renflairApiKey: process.env.RENFLAIR_API_KEY ?? '',
  },
});
