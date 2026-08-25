import { MigrationInterface, QueryRunner } from "typeorm";

export class TournamentRichSpecFields1787495654018 implements MigrationInterface {
    name = 'TournamentRichSpecFields1787495654018'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "logo_url" character varying(512)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "description" text`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "organizer_name" character varying(255)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "contact_email" character varying(255)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "contact_phone" character varying(32)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "location" character varying(255)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "number_of_teams" integer`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "max_players_per_team" integer`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "tournament_rules" text`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "match_rules" text`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "points_system" text`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "tie_breaker_rules" text`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "registration_opens_at" date`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "registration_closes_at" date`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "player_registration_fee" numeric(12,2)`);
        await queryRunner.query(`ALTER TABLE "tournaments" ADD "team_registration_fee" numeric(12,2)`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "team_registration_fee"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "player_registration_fee"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "registration_closes_at"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "registration_opens_at"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "tie_breaker_rules"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "points_system"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "match_rules"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "tournament_rules"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "max_players_per_team"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "number_of_teams"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "location"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "contact_phone"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "contact_email"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "organizer_name"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "description"`);
        await queryRunner.query(`ALTER TABLE "tournaments" DROP COLUMN "logo_url"`);
    }

}
