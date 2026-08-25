import { MigrationInterface, QueryRunner } from "typeorm";

export class MatchesModule1787506307612 implements MigrationInterface {
    name = 'MatchesModule1787506307612'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."matches_status_enum" AS ENUM('scheduled', 'live', 'completed', 'cancelled')`);
        await queryRunner.query(`CREATE TABLE "matches" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_id" uuid NOT NULL, "home_tournament_team_id" uuid, "away_tournament_team_id" uuid, "scheduled_at" TIMESTAMP WITH TIME ZONE, "venue_name" character varying(255), "umpire_name" character varying(255), "scorer_name" character varying(255), "status" "public"."matches_status_enum" NOT NULL DEFAULT 'scheduled', "result_summary" text, "winner_tournament_team_id" uuid, "created_by_user_id" uuid NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_8a22c7b2e0828988d51256117f4" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_d0fb132a9b17b5801b91666214" ON "matches" ("tournament_id") `);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_d0fb132a9b17b5801b916662147" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_51e85c519d7ba1b196c41a8ed1d" FOREIGN KEY ("home_tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_be1cbc1cbdabbb91aa96cb2c34e" FOREIGN KEY ("away_tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_c8a51c6bafb8cf803e4ae725ea3" FOREIGN KEY ("winner_tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_9d761d3a02569698091a3a29f3c" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_9d761d3a02569698091a3a29f3c"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_c8a51c6bafb8cf803e4ae725ea3"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_be1cbc1cbdabbb91aa96cb2c34e"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_51e85c519d7ba1b196c41a8ed1d"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_d0fb132a9b17b5801b916662147"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_d0fb132a9b17b5801b91666214"`);
        await queryRunner.query(`DROP TABLE "matches"`);
        await queryRunner.query(`DROP TYPE "public"."matches_status_enum"`);
    }

}
