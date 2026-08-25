import { MigrationInterface, QueryRunner } from "typeorm";

export class PracticeManagementModule1787508777660 implements MigrationInterface {
    name = 'PracticeManagementModule1787508777660'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."coaches_status_enum" AS ENUM('active', 'inactive')`);
        await queryRunner.query(`CREATE TABLE "coaches" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "full_name" character varying(255) NOT NULL, "phone" character varying(32), "email" character varying(255), "specialization" character varying(100), "photo_url" character varying(512), "status" "public"."coaches_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_eddaece1a1f1b197fa39e6864a1" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_74e50499ab13e2ae2ca9dd2e39" ON "coaches" ("organization_id") `);
        await queryRunner.query(`CREATE TYPE "public"."practice_sessions_practice_type_enum" AS ENUM('batting', 'bowling', 'fielding', 'fitness', 'net_practice', 'strategy_session')`);
        await queryRunner.query(`CREATE TYPE "public"."practice_sessions_status_enum" AS ENUM('scheduled', 'completed', 'cancelled')`);
        await queryRunner.query(`CREATE TABLE "practice_sessions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "team_id" uuid NOT NULL, "coach_id" uuid, "scheduled_at" TIMESTAMP WITH TIME ZONE NOT NULL, "venue_name" character varying(255), "practice_type" "public"."practice_sessions_practice_type_enum" NOT NULL, "duration_minutes" integer, "notes" text, "status" "public"."practice_sessions_status_enum" NOT NULL DEFAULT 'scheduled', "created_by_user_id" uuid NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_70d97b1cdd66f9b01bd492b92fc" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_c5997424a8f2327501be67dd54" ON "practice_sessions" ("organization_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_8cb10a4b735a3dddf79f453d68" ON "practice_sessions" ("team_id") `);
        await queryRunner.query(`CREATE TYPE "public"."practice_attendance_status_enum" AS ENUM('present', 'absent')`);
        await queryRunner.query(`CREATE TABLE "practice_attendance" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "practice_session_id" uuid NOT NULL, "player_id" uuid NOT NULL, "status" "public"."practice_attendance_status_enum" NOT NULL DEFAULT 'absent', "marked_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "uq_practice_attendance_session_player" UNIQUE ("practice_session_id", "player_id"), CONSTRAINT "PK_f240be292dbd7520c666be9fdec" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_13038914344134fa42ffd029d2" ON "practice_attendance" ("practice_session_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_0209731e0afa03ca3cf2b77af7" ON "practice_attendance" ("player_id") `);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum" RENAME TO "match_lineups_role_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum" USING "role"::"text"::"public"."match_lineups_role_enum"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`ALTER TABLE "coaches" ADD CONSTRAINT "FK_74e50499ab13e2ae2ca9dd2e395" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" ADD CONSTRAINT "FK_c5997424a8f2327501be67dd541" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" ADD CONSTRAINT "FK_8cb10a4b735a3dddf79f453d685" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" ADD CONSTRAINT "FK_4dec3f731a49272257da232c2cc" FOREIGN KEY ("coach_id") REFERENCES "coaches"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" ADD CONSTRAINT "FK_31cf4d30f8afff8f135afd202b7" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_attendance" ADD CONSTRAINT "FK_13038914344134fa42ffd029d2b" FOREIGN KEY ("practice_session_id") REFERENCES "practice_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "practice_attendance" ADD CONSTRAINT "FK_0209731e0afa03ca3cf2b77af73" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "practice_attendance" DROP CONSTRAINT "FK_0209731e0afa03ca3cf2b77af73"`);
        await queryRunner.query(`ALTER TABLE "practice_attendance" DROP CONSTRAINT "FK_13038914344134fa42ffd029d2b"`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" DROP CONSTRAINT "FK_31cf4d30f8afff8f135afd202b7"`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" DROP CONSTRAINT "FK_4dec3f731a49272257da232c2cc"`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" DROP CONSTRAINT "FK_8cb10a4b735a3dddf79f453d685"`);
        await queryRunner.query(`ALTER TABLE "practice_sessions" DROP CONSTRAINT "FK_c5997424a8f2327501be67dd541"`);
        await queryRunner.query(`ALTER TABLE "coaches" DROP CONSTRAINT "FK_74e50499ab13e2ae2ca9dd2e395"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum_old" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum_old" USING "role"::"text"::"public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum_old" RENAME TO "match_lineups_role_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_0209731e0afa03ca3cf2b77af7"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_13038914344134fa42ffd029d2"`);
        await queryRunner.query(`DROP TABLE "practice_attendance"`);
        await queryRunner.query(`DROP TYPE "public"."practice_attendance_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_8cb10a4b735a3dddf79f453d68"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_c5997424a8f2327501be67dd54"`);
        await queryRunner.query(`DROP TABLE "practice_sessions"`);
        await queryRunner.query(`DROP TYPE "public"."practice_sessions_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."practice_sessions_practice_type_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_74e50499ab13e2ae2ca9dd2e39"`);
        await queryRunner.query(`DROP TABLE "coaches"`);
        await queryRunner.query(`DROP TYPE "public"."coaches_status_enum"`);
    }

}
