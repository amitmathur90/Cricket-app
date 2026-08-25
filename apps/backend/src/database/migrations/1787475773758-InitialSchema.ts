import { MigrationInterface, QueryRunner } from "typeorm";

export class InitialSchema1787475773758 implements MigrationInterface {
    name = 'InitialSchema1787475773758'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."organizations_status_enum" AS ENUM('active', 'suspended')`);
        await queryRunner.query(`CREATE TABLE "organizations" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(255) NOT NULL, "slug" character varying(255) NOT NULL, "logo_url" character varying(512), "subscription_tier" character varying(50) NOT NULL DEFAULT 'free', "status" "public"."organizations_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_963693341bd612aa01ddf3a4b68" UNIQUE ("slug"), CONSTRAINT "PK_6b031fcd0863e3f6b44230163f9" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."users_status_enum" AS ENUM('active', 'suspended')`);
        await queryRunner.query(`CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "email" character varying(255) NOT NULL, "phone" character varying(32), "password_hash" character varying(255) NOT NULL, "full_name" character varying(255) NOT NULL, "avatar_url" character varying(512), "is_super_admin" boolean NOT NULL DEFAULT false, "status" "public"."users_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."org_memberships_role_enum" AS ENUM('org_admin', 'tournament_admin', 'team_owner', 'scorer', 'umpire', 'player', 'viewer')`);
        await queryRunner.query(`CREATE TYPE "public"."org_memberships_status_enum" AS ENUM('invited', 'active', 'removed')`);
        await queryRunner.query(`CREATE TABLE "org_memberships" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "user_id" uuid NOT NULL, "role" "public"."org_memberships_role_enum" NOT NULL, "status" "public"."org_memberships_status_enum" NOT NULL DEFAULT 'active', "invited_by_user_id" uuid, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "uq_org_membership_org_user" UNIQUE ("organization_id", "user_id"), CONSTRAINT "PK_93302068fabd778ba9897219c38" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_56885f8072df21349b71206855" ON "org_memberships" ("organization_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_21620e5f0bf90d145fec09bee9" ON "org_memberships" ("user_id") `);
        await queryRunner.query(`CREATE TABLE "refresh_tokens" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "token_hash" character varying(128) NOT NULL, "device_info" text, "expires_at" TIMESTAMP WITH TIME ZONE NOT NULL, "revoked_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_7d8bee0204106019488c4c50ffa" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_3ddc983c5f7bcf132fd8732c3f" ON "refresh_tokens" ("user_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_a7838d2ba25be1342091b6695f" ON "refresh_tokens" ("token_hash") `);
        await queryRunner.query(`CREATE TYPE "public"."tournaments_format_enum" AS ENUM('t20', 'odi', 't10', 'custom')`);
        await queryRunner.query(`CREATE TYPE "public"."tournaments_status_enum" AS ENUM('draft', 'upcoming', 'live', 'completed')`);
        await queryRunner.query(`CREATE TABLE "tournaments" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "name" character varying(255) NOT NULL, "format" "public"."tournaments_format_enum" NOT NULL, "start_date" date NOT NULL, "end_date" date NOT NULL, "status" "public"."tournaments_status_enum" NOT NULL DEFAULT 'draft', "auction_enabled" boolean NOT NULL DEFAULT false, "created_by_user_id" uuid NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_6d5d129da7a80cf99e8ad4833a9" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_0c4a9589d0ce3dd50c22e8db7d" ON "tournaments" ("organization_id") `);
        await queryRunner.query(`CREATE TABLE "tournament_groups" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_id" uuid NOT NULL, "name" character varying(255) NOT NULL, CONSTRAINT "PK_c2f8cd1faeb19919d97022068df" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_00ebc8223cd16a064947b675f3" ON "tournament_groups" ("tournament_id") `);
        await queryRunner.query(`CREATE TABLE "teams" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "name" character varying(255) NOT NULL, "short_code" character varying(16), "logo_url" character varying(512), "owner_user_id" uuid, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_7e5523774a38b08a6236d322403" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_fdc736f761896ccc179c823a78" ON "teams" ("organization_id") `);
        await queryRunner.query(`CREATE TYPE "public"."tournament_teams_status_enum" AS ENUM('registered', 'withdrawn')`);
        await queryRunner.query(`CREATE TABLE "tournament_teams" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_id" uuid NOT NULL, "team_id" uuid NOT NULL, "group_id" uuid, "status" "public"."tournament_teams_status_enum" NOT NULL DEFAULT 'registered', "purse_total" numeric(12,2), "purse_remaining" numeric(12,2), CONSTRAINT "uq_tournament_team" UNIQUE ("tournament_id", "team_id"), CONSTRAINT "PK_e5e9835d1cc7678bc6f8b9cb4cc" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_1a8faed6cf5e1669d40b3a8b76" ON "tournament_teams" ("tournament_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_2e3297dc33a4087af1c1bf4c64" ON "tournament_teams" ("team_id") `);
        await queryRunner.query(`CREATE TYPE "public"."players_role_enum" AS ENUM('batsman', 'bowler', 'all_rounder', 'wicketkeeper')`);
        await queryRunner.query(`CREATE TYPE "public"."players_status_enum" AS ENUM('active', 'inactive')`);
        await queryRunner.query(`CREATE TABLE "players" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "organization_id" uuid NOT NULL, "user_id" uuid, "full_name" character varying(255) NOT NULL, "dob" date, "role" "public"."players_role_enum" NOT NULL, "batting_style" character varying(50), "bowling_style" character varying(50), "photo_url" character varying(512), "base_price" numeric(12,2), "status" "public"."players_status_enum" NOT NULL DEFAULT 'active', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_de22b8fdeee0c33ab55ae71da3b" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_a52d95e593ecb08cf7f6b21fab" ON "players" ("organization_id") `);
        await queryRunner.query(`CREATE TYPE "public"."team_players_acquisition_type_enum" AS ENUM('auction', 'direct_signing', 'retained')`);
        await queryRunner.query(`CREATE TYPE "public"."team_players_status_enum" AS ENUM('active', 'released')`);
        await queryRunner.query(`CREATE TABLE "team_players" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_team_id" uuid NOT NULL, "player_id" uuid NOT NULL, "jersey_number" integer, "is_captain" boolean NOT NULL DEFAULT false, "is_wicketkeeper" boolean NOT NULL DEFAULT false, "acquisition_type" "public"."team_players_acquisition_type_enum" NOT NULL DEFAULT 'direct_signing', "acquired_price" numeric(12,2), "status" "public"."team_players_status_enum" NOT NULL DEFAULT 'active', CONSTRAINT "uq_team_player" UNIQUE ("tournament_team_id", "player_id"), CONSTRAINT "PK_e5cc65b0865477e94f8c08af216" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_ddf083105d9ce51da322e5b6ca" ON "team_players" ("tournament_team_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_187fdfeb2ca268cf6b93e89ce1" ON "team_players" ("player_id") `);
        await queryRunner.query(`ALTER TABLE "org_memberships" ADD CONSTRAINT "FK_56885f8072df21349b71206855d" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "org_memberships" ADD CONSTRAINT "FK_21620e5f0bf90d145fec09bee9c" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "org_memberships" ADD CONSTRAINT "FK_91161ce7c202ffd58cbb630b07f" FOREIGN KEY ("invited_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "refresh_tokens" ADD CONSTRAINT "FK_3ddc983c5f7bcf132fd8732c3f4" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD CONSTRAINT "FK_0c4a9589d0ce3dd50c22e8db7de" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD CONSTRAINT "FK_59638c256364a766a721a4408ee" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_groups" ADD CONSTRAINT "FK_00ebc8223cd16a064947b675f34" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "teams" ADD CONSTRAINT "FK_fdc736f761896ccc179c823a785" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "teams" ADD CONSTRAINT "FK_13f00abf7cb6096c43ecaf8c108" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" ADD CONSTRAINT "FK_1a8faed6cf5e1669d40b3a8b762" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" ADD CONSTRAINT "FK_2e3297dc33a4087af1c1bf4c645" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" ADD CONSTRAINT "FK_24bc1178daed226e2055a23e26f" FOREIGN KEY ("group_id") REFERENCES "tournament_groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "players" ADD CONSTRAINT "FK_a52d95e593ecb08cf7f6b21fabc" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "players" ADD CONSTRAINT "FK_ba3575d2fbe71fab7155366235e" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "team_players" ADD CONSTRAINT "FK_ddf083105d9ce51da322e5b6cab" FOREIGN KEY ("tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "team_players" ADD CONSTRAINT "FK_187fdfeb2ca268cf6b93e89ce12" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "team_players" DROP CONSTRAINT "FK_187fdfeb2ca268cf6b93e89ce12"`);
        await queryRunner.query(`ALTER TABLE "team_players" DROP CONSTRAINT "FK_ddf083105d9ce51da322e5b6cab"`);
        await queryRunner.query(`ALTER TABLE "players" DROP CONSTRAINT "FK_ba3575d2fbe71fab7155366235e"`);
        await queryRunner.query(`ALTER TABLE "players" DROP CONSTRAINT "FK_a52d95e593ecb08cf7f6b21fabc"`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" DROP CONSTRAINT "FK_24bc1178daed226e2055a23e26f"`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" DROP CONSTRAINT "FK_2e3297dc33a4087af1c1bf4c645"`);
        await queryRunner.query(`ALTER TABLE "tournament_teams" DROP CONSTRAINT "FK_1a8faed6cf5e1669d40b3a8b762"`);
        await queryRunner.query(`ALTER TABLE "teams" DROP CONSTRAINT "FK_13f00abf7cb6096c43ecaf8c108"`);
        await queryRunner.query(`ALTER TABLE "teams" DROP CONSTRAINT "FK_fdc736f761896ccc179c823a785"`);
        await queryRunner.query(`ALTER TABLE "tournament_groups" DROP CONSTRAINT "FK_00ebc8223cd16a064947b675f34"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP CONSTRAINT "FK_59638c256364a766a721a4408ee"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP CONSTRAINT "FK_0c4a9589d0ce3dd50c22e8db7de"`);
        await queryRunner.query(`ALTER TABLE "refresh_tokens" DROP CONSTRAINT "FK_3ddc983c5f7bcf132fd8732c3f4"`);
        await queryRunner.query(`ALTER TABLE "org_memberships" DROP CONSTRAINT "FK_91161ce7c202ffd58cbb630b07f"`);
        await queryRunner.query(`ALTER TABLE "org_memberships" DROP CONSTRAINT "FK_21620e5f0bf90d145fec09bee9c"`);
        await queryRunner.query(`ALTER TABLE "org_memberships" DROP CONSTRAINT "FK_56885f8072df21349b71206855d"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_187fdfeb2ca268cf6b93e89ce1"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_ddf083105d9ce51da322e5b6ca"`);
        await queryRunner.query(`DROP TABLE "team_players"`);
        await queryRunner.query(`DROP TYPE "public"."team_players_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."team_players_acquisition_type_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_a52d95e593ecb08cf7f6b21fab"`);
        await queryRunner.query(`DROP TABLE "players"`);
        await queryRunner.query(`DROP TYPE "public"."players_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."players_role_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_2e3297dc33a4087af1c1bf4c64"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_1a8faed6cf5e1669d40b3a8b76"`);
        await queryRunner.query(`DROP TABLE "tournament_teams"`);
        await queryRunner.query(`DROP TYPE "public"."tournament_teams_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_fdc736f761896ccc179c823a78"`);
        await queryRunner.query(`DROP TABLE "teams"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_00ebc8223cd16a064947b675f3"`);
        await queryRunner.query(`DROP TABLE "tournament_groups"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_0c4a9589d0ce3dd50c22e8db7d"`);
        await queryRunner.query(`DROP TABLE "tournaments"`);
        await queryRunner.query(`DROP TYPE "public"."tournaments_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."tournaments_format_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_a7838d2ba25be1342091b6695f"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_3ddc983c5f7bcf132fd8732c3f"`);
        await queryRunner.query(`DROP TABLE "refresh_tokens"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_21620e5f0bf90d145fec09bee9"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_56885f8072df21349b71206855"`);
        await queryRunner.query(`DROP TABLE "org_memberships"`);
        await queryRunner.query(`DROP TYPE "public"."org_memberships_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."org_memberships_role_enum"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TYPE "public"."users_status_enum"`);
        await queryRunner.query(`DROP TABLE "organizations"`);
        await queryRunner.query(`DROP TYPE "public"."organizations_status_enum"`);
    }

}
