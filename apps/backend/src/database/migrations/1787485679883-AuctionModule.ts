import { MigrationInterface, QueryRunner } from "typeorm";

export class AuctionModule1787485679883 implements MigrationInterface {
    name = 'AuctionModule1787485679883'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."auction_sessions_status_enum" AS ENUM('scheduled', 'live', 'paused', 'completed')`);
        await queryRunner.query(`CREATE TABLE "auction_sessions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_id" uuid NOT NULL, "name" character varying(255) NOT NULL, "status" "public"."auction_sessions_status_enum" NOT NULL DEFAULT 'scheduled', "current_player_id" uuid, "current_bid_amount" numeric(12,2), "current_bid_team_id" uuid, "bid_increment_rules" jsonb, "current_lot_ends_at" TIMESTAMP WITH TIME ZONE, "started_at" TIMESTAMP WITH TIME ZONE, "ended_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_80a48787f611906020883f3f714" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_23cd149cf44e234a7e85719172" ON "auction_sessions" ("tournament_id") `);
        await queryRunner.query(`CREATE TYPE "public"."auction_player_pool_status_enum" AS ENUM('pending', 'in_progress', 'sold', 'unsold')`);
        await queryRunner.query(`CREATE TABLE "auction_player_pool" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "auction_session_id" uuid NOT NULL, "player_id" uuid NOT NULL, "base_price" numeric(12,2) NOT NULL, "status" "public"."auction_player_pool_status_enum" NOT NULL DEFAULT 'pending', "final_price" numeric(12,2), "sold_to_team_id" uuid, "lot_order" integer NOT NULL, CONSTRAINT "uq_auction_pool_session_player" UNIQUE ("auction_session_id", "player_id"), CONSTRAINT "PK_8835ab8b9d7b10d24c273809fa6" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_f2bbbd618f553a1e4e335c27d9" ON "auction_player_pool" ("auction_session_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_cc618929ff8c7b2656dff5abca" ON "auction_player_pool" ("player_id") `);
        await queryRunner.query(`CREATE TABLE "auction_bids" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "auction_session_id" uuid NOT NULL, "auction_player_pool_id" uuid NOT NULL, "team_id" uuid NOT NULL, "bid_amount" numeric(12,2) NOT NULL, "bid_sequence" integer NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_75fb5ac3cf131789bf7c5181efb" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_a1d89ac08bf43d6abf6d945fa0" ON "auction_bids" ("auction_session_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_0a60681df9dbcca3384e6c1c95" ON "auction_bids" ("auction_player_pool_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_018f2ed45e7eb96fdd29f95c29" ON "auction_bids" ("team_id") `);
        await queryRunner.query(`CREATE TYPE "public"."purse_ledger_type_enum" AS ENUM('debit', 'credit')`);
        await queryRunner.query(`CREATE TABLE "purse_ledger" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "tournament_team_id" uuid NOT NULL, "auction_session_id" uuid, "player_id" uuid, "amount" numeric(12,2) NOT NULL, "type" "public"."purse_ledger_type_enum" NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_4222b403371f943fc67832c6d30" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_58054c54871b2d8acac83047d0" ON "purse_ledger" ("tournament_team_id") `);
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD CONSTRAINT "FK_23cd149cf44e234a7e857191726" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD CONSTRAINT "FK_d84e717f975050af68f4d352905" FOREIGN KEY ("current_player_id") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" ADD CONSTRAINT "FK_3a8e2d5096fcd8e5351dccf1b5f" FOREIGN KEY ("current_bid_team_id") REFERENCES "tournament_teams"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" ADD CONSTRAINT "FK_f2bbbd618f553a1e4e335c27d91" FOREIGN KEY ("auction_session_id") REFERENCES "auction_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" ADD CONSTRAINT "FK_cc618929ff8c7b2656dff5abca2" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" ADD CONSTRAINT "FK_2117a8f7b44ea8151f43d5a8fd7" FOREIGN KEY ("sold_to_team_id") REFERENCES "tournament_teams"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_bids" ADD CONSTRAINT "FK_a1d89ac08bf43d6abf6d945fa02" FOREIGN KEY ("auction_session_id") REFERENCES "auction_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_bids" ADD CONSTRAINT "FK_0a60681df9dbcca3384e6c1c95f" FOREIGN KEY ("auction_player_pool_id") REFERENCES "auction_player_pool"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "auction_bids" ADD CONSTRAINT "FK_018f2ed45e7eb96fdd29f95c29d" FOREIGN KEY ("team_id") REFERENCES "tournament_teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "purse_ledger" ADD CONSTRAINT "FK_58054c54871b2d8acac83047d04" FOREIGN KEY ("tournament_team_id") REFERENCES "tournament_teams"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "purse_ledger" ADD CONSTRAINT "FK_4ac5b2d11fc3c4bbd632ff1897c" FOREIGN KEY ("auction_session_id") REFERENCES "auction_sessions"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "purse_ledger" ADD CONSTRAINT "FK_a05d3e51416570cc6cdbc14c3b9" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "purse_ledger" DROP CONSTRAINT "FK_a05d3e51416570cc6cdbc14c3b9"`);
        await queryRunner.query(`ALTER TABLE "purse_ledger" DROP CONSTRAINT "FK_4ac5b2d11fc3c4bbd632ff1897c"`);
        await queryRunner.query(`ALTER TABLE "purse_ledger" DROP CONSTRAINT "FK_58054c54871b2d8acac83047d04"`);
        await queryRunner.query(`ALTER TABLE "auction_bids" DROP CONSTRAINT "FK_018f2ed45e7eb96fdd29f95c29d"`);
        await queryRunner.query(`ALTER TABLE "auction_bids" DROP CONSTRAINT "FK_0a60681df9dbcca3384e6c1c95f"`);
        await queryRunner.query(`ALTER TABLE "auction_bids" DROP CONSTRAINT "FK_a1d89ac08bf43d6abf6d945fa02"`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" DROP CONSTRAINT "FK_2117a8f7b44ea8151f43d5a8fd7"`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" DROP CONSTRAINT "FK_cc618929ff8c7b2656dff5abca2"`);
        await queryRunner.query(`ALTER TABLE "auction_player_pool" DROP CONSTRAINT "FK_f2bbbd618f553a1e4e335c27d91"`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP CONSTRAINT "FK_3a8e2d5096fcd8e5351dccf1b5f"`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP CONSTRAINT "FK_d84e717f975050af68f4d352905"`);
        await queryRunner.query(`ALTER TABLE "auction_sessions" DROP CONSTRAINT "FK_23cd149cf44e234a7e857191726"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_58054c54871b2d8acac83047d0"`);
        await queryRunner.query(`DROP TABLE "purse_ledger"`);
        await queryRunner.query(`DROP TYPE "public"."purse_ledger_type_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_018f2ed45e7eb96fdd29f95c29"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_0a60681df9dbcca3384e6c1c95"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_a1d89ac08bf43d6abf6d945fa0"`);
        await queryRunner.query(`DROP TABLE "auction_bids"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_cc618929ff8c7b2656dff5abca"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_f2bbbd618f553a1e4e335c27d9"`);
        await queryRunner.query(`DROP TABLE "auction_player_pool"`);
        await queryRunner.query(`DROP TYPE "public"."auction_player_pool_status_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_23cd149cf44e234a7e85719172"`);
        await queryRunner.query(`DROP TABLE "auction_sessions"`);
        await queryRunner.query(`DROP TYPE "public"."auction_sessions_status_enum"`);
    }

}
