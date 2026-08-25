import { MigrationInterface, QueryRunner } from "typeorm";

export class ScoringModule1787540346526 implements MigrationInterface {
    name = 'ScoringModule1787540346526'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."innings_status_enum" AS ENUM('in_progress', 'completed')`);
        await queryRunner.query(`CREATE TABLE "innings" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "match_id" uuid NOT NULL, "innings_number" integer NOT NULL, "batting_tournament_team_id" uuid NOT NULL, "bowling_tournament_team_id" uuid NOT NULL, "total_runs" integer NOT NULL DEFAULT '0', "total_wickets" integer NOT NULL DEFAULT '0', "total_overs_bowled" numeric(5,1) NOT NULL DEFAULT '0', "extras_total" integer NOT NULL DEFAULT '0', "status" "public"."innings_status_enum" NOT NULL DEFAULT 'in_progress', "current_striker_team_player_id" uuid, "current_non_striker_team_player_id" uuid, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_e99f5eaa5bead229b05574e2228" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_4d4444de7c7b2cd38d04416392" ON "innings" ("match_id") `);
        await queryRunner.query(`CREATE TYPE "public"."overs_status_enum" AS ENUM('in_progress', 'completed')`);
        await queryRunner.query(`CREATE TABLE "overs" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "innings_id" uuid NOT NULL, "over_number" integer NOT NULL, "bowler_team_player_id" uuid NOT NULL, "runs_conceded" integer NOT NULL DEFAULT '0', "wickets" integer NOT NULL DEFAULT '0', "is_maiden" boolean NOT NULL DEFAULT false, "status" "public"."overs_status_enum" NOT NULL DEFAULT 'in_progress', CONSTRAINT "PK_9764eea903958f081648ba306b0" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_b75b221caabd499eec309ef3e7" ON "overs" ("innings_id") `);
        await queryRunner.query(`CREATE TYPE "public"."balls_extra_type_enum" AS ENUM('wide', 'no_ball', 'bye', 'leg_bye', 'penalty')`);
        await queryRunner.query(`CREATE TYPE "public"."balls_dismissal_type_enum" AS ENUM('bowled', 'caught', 'lbw', 'run_out', 'stumped', 'hit_wicket', 'retired_hurt')`);
        await queryRunner.query(`CREATE TABLE "balls" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "innings_id" uuid NOT NULL, "over_id" uuid NOT NULL, "ball_number_in_over" integer NOT NULL, "striker_team_player_id" uuid NOT NULL, "non_striker_team_player_id" uuid NOT NULL, "bowler_team_player_id" uuid NOT NULL, "runs_batter" integer NOT NULL DEFAULT '0', "runs_extra" integer NOT NULL DEFAULT '0', "extra_type" "public"."balls_extra_type_enum", "is_wicket" boolean NOT NULL DEFAULT false, "dismissal_type" "public"."balls_dismissal_type_enum", "dismissed_team_player_id" uuid, "fielder_team_player_id" uuid, "next_batter_team_player_id" uuid, "commentary_text" text, "sequence_number" integer NOT NULL, "voided" boolean NOT NULL DEFAULT false, "voided_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_e1e6e9d5f1b9914a28e6ac1a892" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_3e23846941d8fd33f04f44abcb" ON "balls" ("innings_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_dd82df051e1b3472dec0d4d559" ON "balls" ("over_id") `);
        await queryRunner.query(`CREATE TABLE "partnerships" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "innings_id" uuid NOT NULL, "batter1_team_player_id" uuid NOT NULL, "batter2_team_player_id" uuid NOT NULL, "start_ball_sequence" integer NOT NULL, "end_ball_sequence" integer, "runs" integer NOT NULL DEFAULT '0', "balls_faced" integer NOT NULL DEFAULT '0', CONSTRAINT "PK_55de3c169ff0d5d88e9a7cb0cd6" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_15e8f65eab439610c341b73d02" ON "partnerships" ("innings_id") `);
        await queryRunner.query(`ALTER TABLE "matches" ADD "overs_limit" integer`);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum" RENAME TO "match_lineups_role_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum" USING "role"::"text"::"public"."match_lineups_role_enum"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`ALTER TABLE "innings" ADD CONSTRAINT "FK_4d4444de7c7b2cd38d044163921" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "innings" ADD CONSTRAINT "FK_09ea63b9f5b5171ee0763eec904" FOREIGN KEY ("batting_tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "innings" ADD CONSTRAINT "FK_501910d3f976dedc94b675da56e" FOREIGN KEY ("bowling_tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "innings" ADD CONSTRAINT "FK_74379c9ce28fb5fd2b8adfa9adf" FOREIGN KEY ("current_striker_team_player_id") REFERENCES "team_players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "innings" ADD CONSTRAINT "FK_1908c135f4f7b79fbeebccde6e6" FOREIGN KEY ("current_non_striker_team_player_id") REFERENCES "team_players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "overs" ADD CONSTRAINT "FK_b75b221caabd499eec309ef3e73" FOREIGN KEY ("innings_id") REFERENCES "innings"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "overs" ADD CONSTRAINT "FK_e3fbfbbbb70ea9e61b6b9ee9aca" FOREIGN KEY ("bowler_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_3e23846941d8fd33f04f44abcb9" FOREIGN KEY ("innings_id") REFERENCES "innings"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_dd82df051e1b3472dec0d4d559b" FOREIGN KEY ("over_id") REFERENCES "overs"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_12dcb1321492247f81d674424f4" FOREIGN KEY ("striker_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_e1335d802552ac261ddafac9cac" FOREIGN KEY ("non_striker_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_14b634b04f3d2e59d846ba78dfd" FOREIGN KEY ("bowler_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_8dc3c07d12582059f43aa954229" FOREIGN KEY ("dismissed_team_player_id") REFERENCES "team_players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_a2e55ba540fbecb14b0bb0b4e94" FOREIGN KEY ("fielder_team_player_id") REFERENCES "team_players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "balls" ADD CONSTRAINT "FK_05e752900e81c0a18c78feed6a6" FOREIGN KEY ("next_batter_team_player_id") REFERENCES "team_players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "partnerships" ADD CONSTRAINT "FK_15e8f65eab439610c341b73d025" FOREIGN KEY ("innings_id") REFERENCES "innings"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "partnerships" ADD CONSTRAINT "FK_451f2400876176f3e66901457c0" FOREIGN KEY ("batter1_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "partnerships" ADD CONSTRAINT "FK_23fd2359fb3d034346300993d02" FOREIGN KEY ("batter2_team_player_id") REFERENCES "team_players"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "partnerships" DROP CONSTRAINT "FK_23fd2359fb3d034346300993d02"`);
        await queryRunner.query(`ALTER TABLE "partnerships" DROP CONSTRAINT "FK_451f2400876176f3e66901457c0"`);
        await queryRunner.query(`ALTER TABLE "partnerships" DROP CONSTRAINT "FK_15e8f65eab439610c341b73d025"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_05e752900e81c0a18c78feed6a6"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_a2e55ba540fbecb14b0bb0b4e94"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_8dc3c07d12582059f43aa954229"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_14b634b04f3d2e59d846ba78dfd"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_e1335d802552ac261ddafac9cac"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_12dcb1321492247f81d674424f4"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_dd82df051e1b3472dec0d4d559b"`);
        await queryRunner.query(`ALTER TABLE "balls" DROP CONSTRAINT "FK_3e23846941d8fd33f04f44abcb9"`);
        await queryRunner.query(`ALTER TABLE "overs" DROP CONSTRAINT "FK_e3fbfbbbb70ea9e61b6b9ee9aca"`);
        await queryRunner.query(`ALTER TABLE "overs" DROP CONSTRAINT "FK_b75b221caabd499eec309ef3e73"`);
        await queryRunner.query(`ALTER TABLE "innings" DROP CONSTRAINT "FK_1908c135f4f7b79fbeebccde6e6"`);
        await queryRunner.query(`ALTER TABLE "innings" DROP CONSTRAINT "FK_74379c9ce28fb5fd2b8adfa9adf"`);
        await queryRunner.query(`ALTER TABLE "innings" DROP CONSTRAINT "FK_501910d3f976dedc94b675da56e"`);
        await queryRunner.query(`ALTER TABLE "innings" DROP CONSTRAINT "FK_09ea63b9f5b5171ee0763eec904"`);
        await queryRunner.query(`ALTER TABLE "innings" DROP CONSTRAINT "FK_4d4444de7c7b2cd38d044163921"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum_old" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum_old" USING "role"::"text"::"public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum_old" RENAME TO "match_lineups_role_enum"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP COLUMN "overs_limit"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_15e8f65eab439610c341b73d02"`);
        await queryRunner.query(`DROP TABLE "partnerships"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_dd82df051e1b3472dec0d4d559"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_3e23846941d8fd33f04f44abcb"`);
        await queryRunner.query(`DROP TABLE "balls"`);
        await queryRunner.query(`DROP TYPE "public"."balls_dismissal_type_enum"`);
        await queryRunner.query(`DROP TYPE "public"."balls_extra_type_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_b75b221caabd499eec309ef3e7"`);
        await queryRunner.query(`DROP TABLE "overs"`);
        await queryRunner.query(`DROP TYPE "public"."overs_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_4d4444de7c7b2cd38d04416392"`);
        await queryRunner.query(`DROP TABLE "innings"`);
        await queryRunner.query(`DROP TYPE "public"."innings_status_enum"`);
    }

}
