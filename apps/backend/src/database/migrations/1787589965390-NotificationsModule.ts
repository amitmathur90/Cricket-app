import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * Adds the `notifications` table (in-app Notification Center) AND the
 * `posts` table (news/media, public fan section) — two features built
 * concurrently by separate agents that both generated against the same
 * dev database. Both tables were actually created under this migration's
 * name/timestamp; this file was briefly hand-trimmed to `notifications`
 * only (to describe "just this task's own change") but that left a gap —
 * the live DB has `posts` too, so a fresh install from empty using the
 * trimmed file would silently be missing it. Restored here so the file on
 * disk matches what's genuinely been applied, keeping migration history a
 * reliable record of the live schema. See post.entity.ts / Posts module
 * for that feature's own scope.
 */
export class NotificationsModule1787589965390 implements MigrationInterface {
    name = 'NotificationsModule1787589965390'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."notifications_type_enum" AS ENUM('match_reminder', 'practice_reminder', 'auction_announcement', 'player_approval', 'team_selection', 'match_result', 'schedule_change', 'payment_reminder', 'announcement')`);
        await queryRunner.query(`CREATE TABLE "notifications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "user_id" uuid NOT NULL, "type" "public"."notifications_type_enum" NOT NULL, "title" character varying(255) NOT NULL, "message" text NOT NULL, "related_entity_type" character varying(50), "related_entity_id" uuid, "is_read" boolean NOT NULL DEFAULT false, "read_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_cb7b1fb018b296f2107e998b2f" ON "notifications" ("organization_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_9a8a82462cab47c73d25f49261" ON "notifications" ("user_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_f12148ce379462ebbb4d06cc13" ON "notifications" ("is_read") `);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_cb7b1fb018b296f2107e998b2ff" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_9a8a82462cab47c73d25f49261f" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);

        await queryRunner.query(`CREATE TYPE "public"."posts_type_enum" AS ENUM('news', 'photo', 'video')`);
        await queryRunner.query(`CREATE TABLE "posts" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "tournament_id" uuid, "title" character varying(255) NOT NULL, "body" text NOT NULL, "image_url" character varying(512), "video_url" character varying(512), "type" "public"."posts_type_enum" NOT NULL DEFAULT 'news', "published_at" TIMESTAMP WITH TIME ZONE, "created_by_user_id" uuid NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_2829ac61eff60fcec60d7274b9e" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_47dffb39b4d5ab644bb67bf12d" ON "posts" ("organization_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_f19aa751aaa9b345a8a66d9cd2" ON "posts" ("tournament_id") `);
        await queryRunner.query(`ALTER TABLE "posts" ADD CONSTRAINT "FK_47dffb39b4d5ab644bb67bf12d1" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "posts" ADD CONSTRAINT "FK_f19aa751aaa9b345a8a66d9cd2e" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "posts" ADD CONSTRAINT "FK_65649ac127992f87046f0cd879c" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "posts" DROP CONSTRAINT "FK_65649ac127992f87046f0cd879c"`);
        await queryRunner.query(`ALTER TABLE "posts" DROP CONSTRAINT "FK_f19aa751aaa9b345a8a66d9cd2e"`);
        await queryRunner.query(`ALTER TABLE "posts" DROP CONSTRAINT "FK_47dffb39b4d5ab644bb67bf12d1"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_f19aa751aaa9b345a8a66d9cd2"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_47dffb39b4d5ab644bb67bf12d"`);
        await queryRunner.query(`DROP TABLE "posts"`);
        await queryRunner.query(`DROP TYPE "public"."posts_type_enum"`);

        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_9a8a82462cab47c73d25f49261f"`);
        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_cb7b1fb018b296f2107e998b2ff"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_f12148ce379462ebbb4d06cc13"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_9a8a82462cab47c73d25f49261"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_cb7b1fb018b296f2107e998b2f"`);
        await queryRunner.query(`DROP TABLE "notifications"`);
        await queryRunner.query(`DROP TYPE "public"."notifications_type_enum"`);
    }

}
