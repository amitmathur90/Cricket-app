import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { DataSource, DataSourceOptions } from 'typeorm';
import { allEntities } from './entities';

dotenv.config();

/**
 * Shared TypeORM connection options — used both by the CLI (migration:*
 * npm scripts, via this file directly) and by app.module.ts (wrapped in
 * TypeOrmModule.forRootAsync) so the two never drift apart.
 */
export const dataSourceOptions: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: allEntities,
  migrations: [__dirname + '/migrations/*.{ts,js}'],
  synchronize: false,
  logging: process.env.DB_LOGGING === 'true',
};

export const AppDataSource = new DataSource(dataSourceOptions);
