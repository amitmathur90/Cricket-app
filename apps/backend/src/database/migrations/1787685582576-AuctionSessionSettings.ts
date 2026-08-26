import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * Adds the auction-settings fields introduced when the auto-timer was
 * removed from AuctionRealtimeService in favor of fully manual admin
 * control (mark-sold / mark-unsold / next-lot). See
 * apps/backend/src/database/entities/auction-session.entity.ts's doc
 * comments for what each field means; `current_lot_ends_at` (an existing
 * column) is left in place but unused going forward rather than dropped.
 */
export class AuctionSessionSettings1787685582576 implements MigrationInterface {
    name = 'AuctionSessionSettings1787685582576'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD "duration_minutes" integer`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD "default_team_points" numeric(12,2)`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD "max_squad_size" integer`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP COLUMN "max_squad_size"`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP COLUMN "default_team_points"`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP COLUMN "duration_minutes"`);
    }

}
