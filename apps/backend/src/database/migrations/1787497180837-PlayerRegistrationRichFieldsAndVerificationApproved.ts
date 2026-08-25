import { MigrationInterface, QueryRunner } from "typeorm";

export class PlayerRegistrationRichFieldsAndVerificationApproved1787497180837 implements MigrationInterface {
    name = 'PlayerRegistrationRichFieldsAndVerificationApproved1787497180837'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "players" ADD "gender" character varying(20)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "phone" character varying(32)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "email" character varying(255)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "address" text`);
        await queryRunner.query(`ALTER TABLE "players" ADD "experience" text`);
        await queryRunner.query(`ALTER TABLE "players" ADD "preferred_position" character varying(100)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "address_proof_url" character varying(512)`);
        await queryRunner.query(`ALTER TABLE "players" ADD "other_document_urls" text array`);
        await queryRunner.query(`ALTER TABLE "players" ADD "is_available_for_tournaments" boolean NOT NULL DEFAULT true`);
        await queryRunner.query(`ALTER TABLE "players" ADD "is_available_for_matches" boolean NOT NULL DEFAULT true`);
        await queryRunner.query(`ALTER TABLE "players" ADD "is_available_for_practice" boolean NOT NULL DEFAULT true`);
        await queryRunner.query(`ALTER TABLE "auction_bids" ADD "voided" boolean NOT NULL DEFAULT false`);
        await queryRunner.query(`ALTER TABLE "auction_bids" ADD "voided_at" TIMESTAMP WITH TIME ZONE`);
        await queryRunner.query(`ALTER TYPE "public"."players_verification_status_enum" RENAME TO "players_verification_status_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."players_verification_status_enum" AS ENUM('pending', 'verified', 'approved', 'rejected')`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" TYPE "public"."players_verification_status_enum" USING "verification_status"::"text"::"public"."players_verification_status_enum"`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" SET DEFAULT 'pending'`);
        await queryRunner.query(`DROP TYPE "public"."players_verification_status_enum_old"`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."players_verification_status_enum_old" AS ENUM('pending', 'verified', 'rejected')`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" TYPE "public"."players_verification_status_enum_old" USING "verification_status"::"text"::"public"."players_verification_status_enum_old"`);
        await queryRunner.query(`ALTER TABLE "players" ALTER COLUMN "verification_status" SET DEFAULT 'pending'`);
        await queryRunner.query(`DROP TYPE "public"."players_verification_status_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."players_verification_status_enum_old" RENAME TO "players_verification_status_enum"`);
        await queryRunner.query(`ALTER TABLE "auction_bids" DROP COLUMN "voided_at"`);
        await queryRunner.query(`ALTER TABLE "auction_bids" DROP COLUMN "voided"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "is_available_for_practice"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "is_available_for_matches"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "is_available_for_tournaments"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "other_document_urls"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "address_proof_url"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "preferred_position"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "experience"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "address"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "email"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "phone"`);
        await queryRunner.query(`ALTER TABLE "players" DROP COLUMN "gender"`);
    }

}
