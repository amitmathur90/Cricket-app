import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * Adds the `mobile_login_otps` table backing "Login with mobile OTP"
 * (AuthService.requestMobileLoginOtp/verifyMobileLoginOtp) — see
 * MobileLoginOtp entity's doc comment.
 */
export class MobileLoginOtps1790504057464 implements MigrationInterface {
    name = 'MobileLoginOtps1790504057464'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "mobile_login_otps" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "otp_hash" character varying(128) NOT NULL, "otp_expires_at" TIMESTAMP WITH TIME ZONE NOT NULL, "otp_attempts" integer NOT NULL DEFAULT 0, "consumed_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_mobile_login_otps_id" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_mobile_login_otps_user_id" ON "mobile_login_otps" ("user_id") `);
        await queryRunner.query(`ALTER TABLE "mobile_login_otps" ADD CONSTRAINT "FK_mobile_login_otps_user_id" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "mobile_login_otps" DROP CONSTRAINT "FK_mobile_login_otps_user_id"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_mobile_login_otps_user_id"`);
        await queryRunner.query(`DROP TABLE "mobile_login_otps"`);
    }

}
