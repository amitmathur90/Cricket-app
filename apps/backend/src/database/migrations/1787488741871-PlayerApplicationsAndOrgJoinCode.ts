import * as crypto from "crypto";
import { MigrationInterface, QueryRunner } from "typeorm";

// Same alphabet/length as OrganizationsService's join-code generator —
// duplicated here since migrations must not import application code.
const JOIN_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const JOIN_CODE_LENGTH = 8;

export class PlayerApplicationsAndOrgJoinCode1787488741871 implements MigrationInterface {
    name = 'PlayerApplicationsAndOrgJoinCode1787488741871'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."tournament_applications_status_enum" AS ENUM('pending', 'approved', 'rejected')`);
        await queryRunner.query(`CREATE TABLE "tournament_applications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_id" uuid NOT NULL, "user_id" uuid NOT NULL, "player_id" uuid, "status" "public"."tournament_applications_status_enum" NOT NULL DEFAULT 'pending', "review_note" character varying(255), "reviewed_by_user_id" uuid, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "reviewed_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "uq_tournament_application_tournament_user" UNIQUE ("tournament_id", "user_id"), CONSTRAINT "PK_d37959c8aa640c94992dc7b0c12" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_fe956d824618dfcac63d230a96" ON "tournament_applications" ("tournament_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_f1bd3179a7bbb8f88741275328" ON "tournament_applications" ("user_id") `);
        // Added nullable first so existing rows can be backfilled with a
        // unique code before the NOT NULL + UNIQUE constraints are applied.
        await queryRunner.query(`ALTER TABLE "organizations" ADD "join_code" character varying(8)`);
        await this.backfillJoinCodes(queryRunner);
        await queryRunner.query(`ALTER TABLE "organizations" ALTER COLUMN "join_code" SET NOT NULL`);
        await queryRunner.query(`ALTER TABLE "organizations" ADD CONSTRAINT "UQ_5f5d3c61206a0ea4d0582a33a2b" UNIQUE ("join_code")`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" ADD CONSTRAINT "FK_fe956d824618dfcac63d230a966" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" ADD CONSTRAINT "FK_f1bd3179a7bbb8f88741275328a" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" ADD CONSTRAINT "FK_e47cb8dab4ce790dbc73465ef77" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" ADD CONSTRAINT "FK_7818596e9397d80dbebeb58fe0e" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "tournament_applications" DROP CONSTRAINT "FK_7818596e9397d80dbebeb58fe0e"`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" DROP CONSTRAINT "FK_e47cb8dab4ce790dbc73465ef77"`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" DROP CONSTRAINT "FK_f1bd3179a7bbb8f88741275328a"`);
        await queryRunner.query(`ALTER TABLE "tournament_applications" DROP CONSTRAINT "FK_fe956d824618dfcac63d230a966"`);
        await queryRunner.query(`ALTER TABLE "organizations" DROP CONSTRAINT "UQ_5f5d3c61206a0ea4d0582a33a2b"`);
        await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN "join_code"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_f1bd3179a7bbb8f88741275328"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_fe956d824618dfcac63d230a96"`);
        await queryRunner.query(`DROP TABLE "tournament_applications"`);
        await queryRunner.query(`DROP TYPE "public"."tournament_applications_status_enum"`);
    }

    /** Backfills a unique join_code for every pre-existing organizations row. */
    private async backfillJoinCodes(queryRunner: QueryRunner): Promise<void> {
        const rows: Array<{ id: string }> = await queryRunner.query(
            `SELECT "id" FROM "organizations" WHERE "join_code" IS NULL`,
        );
        const usedCodes = new Set<string>();
        for (const row of rows) {
            let code = this.generateJoinCode();
            while (usedCodes.has(code)) {
                code = this.generateJoinCode();
            }
            usedCodes.add(code);
            await queryRunner.query(`UPDATE "organizations" SET "join_code" = $1 WHERE "id" = $2`, [
                code,
                row.id,
            ]);
        }
    }

    private generateJoinCode(): string {
        const bytes = crypto.randomBytes(JOIN_CODE_LENGTH);
        let code = '';
        for (let i = 0; i < JOIN_CODE_LENGTH; i++) {
            code += JOIN_CODE_ALPHABET[bytes[i] % JOIN_CODE_ALPHABET.length];
        }
        return code;
    }

}
