import { plainToInstance } from 'class-transformer';
import { IsBooleanString, IsIn, IsInt, IsOptional, IsString, Max, Min, validateSync } from 'class-validator';

export enum NodeEnv {
  DEVELOPMENT = 'development',
  TEST = 'test',
  PRODUCTION = 'production',
}

class EnvironmentVariables {
  @IsOptional()
  @IsIn([NodeEnv.DEVELOPMENT, NodeEnv.TEST, NodeEnv.PRODUCTION])
  NODE_ENV: NodeEnv = NodeEnv.DEVELOPMENT;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number = 3000;

  @IsString()
  DATABASE_URL: string;

  @IsOptional()
  @IsBooleanString()
  DB_SYNCHRONIZE?: string;

  @IsOptional()
  @IsBooleanString()
  DB_LOGGING?: string;

  @IsString()
  JWT_ACCESS_SECRET: string;

  @IsOptional()
  @IsString()
  JWT_ACCESS_TTL: string = '15m';

  @IsString()
  JWT_REFRESH_SECRET: string;

  @IsOptional()
  @IsString()
  JWT_REFRESH_TTL: string = '30d';

  @IsOptional()
  @IsString()
  CORS_ORIGIN?: string;
}

/**
 * Validated at bootstrap via ConfigModule.forRoot({ validate }). Throws
 * (and fails fast) if required env vars are missing/malformed.
 */
export function validate(config: Record<string, unknown>): EnvironmentVariables {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validatedConfig, { skipMissingProperties: false });

  if (errors.length > 0) {
    throw new Error(`Environment variable validation failed: ${errors.toString()}`);
  }

  return validatedConfig;
}
