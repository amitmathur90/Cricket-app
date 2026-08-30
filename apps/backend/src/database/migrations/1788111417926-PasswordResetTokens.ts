import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * Adds the `password_reset_tokens` table backing the "Forgot password" flow
 * (AuthService.requestPasswordReset/verifyPasswordResetOtp/resetPassword —
 * see PasswordResetToken entity's doc comment for the two-stage OTP ->
 * reset-token lifecycle one row represents).
 */
export class PasswordResetTokens1788111417926 implements MigrationInterface {
    name = 'PasswordResetTokens1788111417926'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "password_reset_tokens" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "otp_hash" character varying(128) NOT NULL, "otp_expires_at" TIMESTAMP WITH TIME ZONE NOT NULL, "otp_attempts" integer NOT NULL DEFAULT 0, "otp_verified_at" TIMESTAMP WITH TIME ZONE, "reset_token_hash" character varying(128), "reset_token_expires_at" TIMESTAMP WITH TIME ZONE, "consumed_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_password_reset_tokens_id" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_password_reset_tokens_user_id" ON "password_reset_tokens" ("user_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_password_reset_tokens_reset_token_hash" ON "password_reset_tokens" ("reset_token_hash") `);
        await queryRunner.query(`ALTER TABLE "password_reset_tokens" ADD CONSTRAINT "FK_password_reset_tokens_user_id" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "password_reset_tokens" DROP CONSTRAINT "FK_password_reset_tokens_user_id"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_password_reset_tokens_reset_token_hash"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_password_reset_tokens_user_id"`);
        await queryRunner.query(`DROP TABLE "password_reset_tokens"`);
    }

}
