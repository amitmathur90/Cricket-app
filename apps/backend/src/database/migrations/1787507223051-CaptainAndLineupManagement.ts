import { MigrationInterface, QueryRunner } from "typeorm";

export class CaptainAndLineupManagement1787507223051 implements MigrationInterface {
    name = 'CaptainAndLineupManagement1787507223051'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`CREATE TABLE "match_lineups" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "match_id" uuid NOT NULL, "tournament_team_id" uuid NOT NULL, "team_player_id" uuid NOT NULL, "role" "public"."match_lineups_role_enum" NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "uq_match_lineup_team_player" UNIQUE ("match_id", "team_player_id"), CONSTRAINT "PK_79de52f107f93cca28a6929329c" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_90df5204130ca28c11c4b089fd" ON "match_lineups" ("match_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_7e2e8743c44409d0a9bcc26123" ON "match_lineups" ("tournament_team_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_7db14c916aab610ac007a10435" ON "match_lineups" ("team_player_id") `);
        await queryRunner.query(`ALTER TABLE "team_players" ADD "is_vice_captain" boolean NOT NULL DEFAULT false`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ADD CONSTRAINT "FK_90df5204130ca28c11c4b089fde" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ADD CONSTRAINT "FK_7e2e8743c44409d0a9bcc261230" FOREIGN KEY ("tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ADD CONSTRAINT "FK_7db14c916aab610ac007a10435b" FOREIGN KEY ("team_player_id") REFERENCES "team_players"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "match_lineups" DROP CONSTRAINT "FK_7db14c916aab610ac007a10435b"`);
        await queryRunner.query(`ALTER TABLE "match_lineups" DROP CONSTRAINT "FK_7e2e8743c44409d0a9bcc261230"`);
        await queryRunner.query(`ALTER TABLE "match_lineups" DROP CONSTRAINT "FK_90df5204130ca28c11c4b089fde"`);
        await queryRunner.query(`ALTER TABLE "team_players" DROP COLUMN "is_vice_captain"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_7db14c916aab610ac007a10435"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_7e2e8743c44409d0a9bcc26123"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_90df5204130ca28c11c4b089fd"`);
        await queryRunner.query(`DROP TABLE "match_lineups"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum"`);
    }

}
