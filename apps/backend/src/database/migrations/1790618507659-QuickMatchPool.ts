import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * Adds `tournaments.is_quick_match_pool`, marking the one hidden,
 * auto-created tournament per organization that backs "Quick Match" (see
 * Tournament.isQuickMatchPool / QuickMatchService doc comments).
 */
export class QuickMatchPool1790618507659 implements MigrationInterface {
    name = 'QuickMatchPool1790618507659'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "is_quick_match_pool" boolean NOT NULL DEFAULT false`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "is_quick_match_pool"`);
    }

}
