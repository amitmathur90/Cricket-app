import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Sponsor } from '../../database/entities/sponsor.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { MatchesModule } from '../matches/matches.module';
import { PlayersModule } from '../players/players.module';
import { PostsModule } from '../posts/posts.module';
import { ScoringModule } from '../scoring/scoring.module';
import { TournamentsModule } from '../tournaments/tournaments.module';
import { PublicDiscoveryController } from './public-discovery.controller';
import { PublicPlayersController } from './public-players.controller';
import { PublicPostsController } from './public-posts.controller';
import { PublicSponsorsController } from './public-sponsors.controller';
import { PublicTournamentsController } from './public-tournaments.controller';

/**
 * Fully unauthenticated read surface for the mobile app's public fan
 * section (an unauthenticated in-app browse area — NOT a separate public
 * website). Deliberately namespaced under `public/organizations/...`
 * rather than sharing routes with the authenticated `organizations/...`
 * controllers, so there is zero chance of an admin-only route accidentally
 * becoming reachable without a token.
 *
 * === Why omitting @UseGuards(...) here is sufficient ===
 *
 * Every other controller in this codebase applies `JwtAuthGuard` (plus
 * `OrgScopeGuard`/`RolesGuard` where relevant) via a per-controller
 * `@UseGuards(...)` decorator — there is NO global guard registered
 * anywhere:
 *   - `app.module.ts` has no `APP_GUARD` provider in its `providers` array
 *     (the only place a global guard would be wired up).
 *   - A repo-wide search for `APP_GUARD` returns zero matches.
 *   - `main.ts` calls `app.useGlobalPipes(...)` for validation but never
 *     `app.useGlobalGuards(...)`.
 * Since there is no global guard, a controller that simply never applies
 * `@UseGuards(JwtAuthGuard, ...)` is genuinely open — no `@Public()`
 * bypass decorator is needed (that decorator exists so specific ROUTES on
 * an otherwise-guarded controller, like `auth/login`, can opt out of an
 * already-applied per-controller guard; it is not needed here because no
 * guard is applied to these controllers in the first place). This was
 * verified functionally too — see the task's smoke test (every route below
 * called with zero Authorization header and succeeding).
 *
 * === Field-level safety ===
 *
 * Every field returned here is a deliberate choice, not a default. Each
 * controller either (a) queries its repository directly with an explicit
 * `select` allow-list (tournaments, sponsors — see each controller's own
 * doc for exactly what's excluded and why), or (b) reuses an authenticated
 * service's *computation* (`TournamentsService.getPointsTable`,
 * `ScoringRealtimeService.getLiveState`, `MatchesService.findAll`/
 * `findOne`, `PlayersService.getRankings`) — for rankings/points-table/live-
 * score the underlying result was already public-safe as-is (performance
 * figures and names only, no PII) and is returned unmodified; the matches
 * endpoint's result is NOT returned unmodified — it's mapped down to an
 * explicit field set, because MatchesService eager-loads full
 * umpireOfficial/scorerOfficial/matchRefereeOfficial objects that carry
 * `Official.phone`/`Official.email` (PII) — see that controller's own
 * comment.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([Tournament, TournamentTeam, Sponsor]),
    TournamentsModule,
    MatchesModule,
    ScoringModule,
    PlayersModule,
    PostsModule,
  ],
  controllers: [
    PublicTournamentsController,
    PublicDiscoveryController,
    PublicPlayersController,
    PublicSponsorsController,
    PublicPostsController,
  ],
})
export class PublicModule {}
