import { MigrationInterface, QueryRunner } from "typeorm";

export class PlayerRegistrationFields1787482848040 implements MigrationInterface {
    name = 'PlayerRegistrationFields1787482848040'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "players" ADD "id_document_url" character varying(512)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "age_category" character varying(50)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "previous_stats_notes" text`);
        await queryRunner.query(`ALTER TABLE "players" ADD "is_available" boolean NOT NULL DEFAULT true`);
        await queryRunner.query(`ALTER TABLE "players" ADD "unavailability_reason" character varying(255)`);
        await queryRunner.query(`CREATE TYPE "public"."players_verification_status_enum" AS ENUM('pending', 'verified', 'rejected')`);
        await queryRunner.query(`ALTER TABLE "players" ADD "verification_status" "public"."players_verification_status_enum" NOT NULL DEFAULT 'pending'`);
        await queryRunner.query(`ALTER TABLE "players" ADD "verification_note" character varying(255)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "rating" numeric(3,2)`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "rating"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "verification_note"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "verification_status"`);
        await queryRunner.query(`DROP TYPE "public"."players_verification_status_enum"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "unavailability_reason"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "is_available"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "previous_stats_notes"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "age_category"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "id_document_url"`);
    }

}
