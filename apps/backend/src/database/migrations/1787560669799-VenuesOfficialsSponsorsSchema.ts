import { MigrationInterface, QueryRunner } from "typeorm";

export class VenuesOfficialsSponsorsSchema1787560669799 implements MigrationInterface {
    name = 'VenuesOfficialsSponsorsSchema1787560669799'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."officials_role_enum" AS ENUM('umpire', 'scorer', 'match_referee')`);
        await queryRunner.query(`CREATE TYPE "public"."officials_status_enum" AS ENUM('active', 'inactive')`);
        await queryRunner.query(`CREATE TABLE "officials" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "full_name" character varying(255) NOT NULL, "role" "public"."officials_role_enum" NOT NULL, "phone" character varying(32), "email" character varying(255), "photo_url" character varying(512), "status" "public"."officials_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_4e1cbe0d999f0d27205ca7b908d" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_e7ad36026acaec6e7554947a1e" ON "officials" ("organization_id") `);
        await queryRunner.query(`CREATE TYPE "public"."venues_status_enum" AS ENUM('active', 'inactive')`);
        await queryRunner.query(`CREATE TABLE "venues" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "name" character varying(255) NOT NULL, "location" character varying(255), "capacity" integer, "pitch_type" character varying(100), "facilities" text, "photo_url" character varying(512), "status" "public"."venues_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_cb0f885278d12384eb7a81818be" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_d88176e38bb768c1c09d3a5f2e" ON "venues" ("organization_id") `);
        await queryRunner.query(`CREATE TABLE "venue_unavailability" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "venue_id" uuid NOT NULL, "date" date NOT NULL, "reason" character varying(255), "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_9f73fbf3825f33816c19d184b69" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_092b6d38b3d6ee76aa8b659c12" ON "venue_unavailability" ("venue_id") `);
        await queryRunner.query(`CREATE TYPE "public"."sponsors_status_enum" AS ENUM('active', 'inactive')`);
        await queryRunner.query(`CREATE TABLE "sponsors" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "company_name" character varying(255) NOT NULL, "logo_url" character varying(512), "package_name" character varying(100), "amount" numeric(12,2), "contract_start_date" date, "contract_end_date" date, "status" "public"."sponsors_status_enum" NOT NULL DEFAULT 'active', "visible_on_website" boolean NOT NULL DEFAULT false, "visible_on_app" boolean NOT NULL DEFAULT false, "visible_on_match_screen" boolean NOT NULL DEFAULT false, "visible_on_scoreboard" boolean NOT NULL DEFAULT false, "visible_on_social_media" boolean NOT NULL DEFAULT false, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_6d1114fe7e65855154351b66bfc" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_7b5c28e64dfb6502de9c87bca3" ON "sponsors" ("organization_id") `);
        await queryRunner.query(`CREATE TYPE "public"."finance_transactions_category_enum" AS ENUM('sponsorship', 'ground_expense', 'officials_payment', 'other_expense', 'other_income')`);
        await queryRunner.query(`CREATE TYPE "public"."finance_transactions_type_enum" AS ENUM('income', 'expense')`);
        await queryRunner.query(`CREATE TABLE "finance_transactions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "tournament_id" uuid, "category" "public"."finance_transactions_category_enum" NOT NULL, "type" "public"."finance_transactions_type_enum" NOT NULL, "amount" numeric(12,2) NOT NULL, "description" text, "reference_date" date NOT NULL, "created_by_user_id" uuid NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_afa9437df81e95c4295cd52f15f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_5c8da29d8ae2b768d0d8a4f15a" ON "finance_transactions" ("organization_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_9a45d4d3f6dfc353dd3315c54b" ON "finance_transactions" ("tournament_id") `);
        await queryRunner.query(`ALTER TABLE "matches" ADD "venue_id" uuid`);
        await queryRunner.query(`ALTER TABLE "matches" ADD "umpire_official_id" uuid`);
        await queryRunner.query(`ALTER TABLE "matches" ADD "scorer_official_id" uuid`);
        await queryRunner.query(`ALTER TABLE "matches" ADD "match_referee_official_id" uuid`);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum" RENAME TO "match_lineups_role_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum" USING "role"::"text"::"public"."match_lineups_role_enum"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`ALTER TABLE "officials" ADD CONSTRAINT "FK_e7ad36026acaec6e7554947a1e5" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "venues" ADD CONSTRAINT "FK_d88176e38bb768c1c09d3a5f2e2" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_cb90abceb14ab1b73e92823acce" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_d3252e6293e4c86ad80bfeefac1" FOREIGN KEY ("umpire_official_id") REFERENCES "officials"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_3fd8572545d5c1298f71733580d" FOREIGN KEY ("scorer_official_id") REFERENCES "officials"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "matches" ADD CONSTRAINT "FK_10964f99eb0bfd95cf5ff07e8d1" FOREIGN KEY ("match_referee_official_id") REFERENCES "officials"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "venue_unavailability" ADD CONSTRAINT "FK_092b6d38b3d6ee76aa8b659c123" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "sponsors" ADD CONSTRAINT "FK_7b5c28e64dfb6502de9c87bca36" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "finance_transactions" ADD CONSTRAINT "FK_5c8da29d8ae2b768d0d8a4f15a4" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "finance_transactions" ADD CONSTRAINT "FK_9a45d4d3f6dfc353dd3315c54b9" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "finance_transactions" ADD CONSTRAINT "FK_e5b40090cce704bde25da966df8" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "finance_transactions" DROP CONSTRAINT "FK_e5b40090cce704bde25da966df8"`);
        await queryRunner.query(`ALTER TABLE "finance_transactions" DROP CONSTRAINT "FK_9a45d4d3f6dfc353dd3315c54b9"`);
        await queryRunner.query(`ALTER TABLE "finance_transactions" DROP CONSTRAINT "FK_5c8da29d8ae2b768d0d8a4f15a4"`);
        await queryRunner.query(`ALTER TABLE "sponsors" DROP CONSTRAINT "FK_7b5c28e64dfb6502de9c87bca36"`);
        await queryRunner.query(`ALTER TABLE "venue_unavailability" DROP CONSTRAINT "FK_092b6d38b3d6ee76aa8b659c123"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_10964f99eb0bfd95cf5ff07e8d1"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_3fd8572545d5c1298f71733580d"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_d3252e6293e4c86ad80bfeefac1"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP CONSTRAINT "FK_cb90abceb14ab1b73e92823acce"`);
        await queryRunner.query(`ALTER TABLE "venues" DROP CONSTRAINT "FK_d88176e38bb768c1c09d3a5f2e2"`);
        await queryRunner.query(`ALTER TABLE "officials" DROP CONSTRAINT "FK_e7ad36026acaec6e7554947a1e5"`);
        await queryRunner.query(`CREATE TYPE "public"."match_lineups_role_enum_old" AS ENUM('playing', 'substitute')`);
        await queryRunner.query(`ALTER TABLE "match_lineups" ALTER COLUMN "role" TYPE "public"."match_lineups_role_enum_old" USING "role"::"text"::"public"."match_lineups_role_enum_old"`);
        await queryRunner.query(`DROP TYPE "public"."match_lineups_role_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."match_lineups_role_enum_old" RENAME TO "match_lineups_role_enum"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP COLUMN "match_referee_official_id"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP COLUMN "scorer_official_id"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP COLUMN "umpire_official_id"`);
        await queryRunner.query(`ALTER TABLE "matches" DROP COLUMN "venue_id"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_9a45d4d3f6dfc353dd3315c54b"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_5c8da29d8ae2b768d0d8a4f15a"`);
        await queryRunner.query(`DROP TABLE "finance_transactions"`);
        await queryRunner.query(`DROP TYPE "public"."finance_transactions_type_enum"`);
        await queryRunner.query(`DROP TYPE "public"."finance_transactions_category_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_7b5c28e64dfb6502de9c87bca3"`);
        await queryRunner.query(`DROP TABLE "sponsors"`);
        await queryRunner.query(`DROP TYPE "public"."sponsors_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_092b6d38b3d6ee76aa8b659c12"`);
        await queryRunner.query(`DROP TABLE "venue_unavailability"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_d88176e38bb768c1c09d3a5f2e"`);
        await queryRunner.query(`DROP TABLE "venues"`);
        await queryRunner.query(`DROP TYPE "public"."venues_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_e7ad36026acaec6e7554947a1e"`);
        await queryRunner.query(`DROP TABLE "officials"`);
        await queryRunner.query(`DROP TYPE "public"."officials_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."officials_role_enum"`);
    }

}
