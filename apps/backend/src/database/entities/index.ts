export * from './organization.entity';
export * from './user.entity';
export * from './org-membership.entity';
export * from './refresh-token.entity';
export * from './tournament.entity';
export * from './tournament-group.entity';
export * from './team.entity';
export * from './tournament-team.entity';
export * from './player.entity';
export * from './team-player.entity';
export * from './auction-session.entity';
export * from './auction-player-pool.entity';
export * from './auction-bid.entity';
export * from './purse-ledger.entity';
export * from './tournament-application.entity';
export * from './match.entity';
export * from './match-lineup.entity';
export * from './coach.entity';
export * from './practice-session.entity';
export * from './practice-attendance.entity';
export * from './innings.entity';
export * from './over.entity';
export * from './ball.entity';
export * from './partnership.entity';
export * from './venue.entity';
export * from './venue-unavailability.entity';
export * from './official.entity';
export * from './sponsor.entity';
export * from './finance-transaction.entity';
export * from './post.entity';
export * from './notification.entity';

import { Organization } from './organization.entity';
import { User } from './user.entity';
import { OrgMembership } from './org-membership.entity';
import { RefreshToken } from './refresh-token.entity';
import { Tournament } from './tournament.entity';
import { TournamentGroup } from './tournament-group.entity';
import { Team } from './team.entity';
import { TournamentTeam } from './tournament-team.entity';
import { Player } from './player.entity';
import { TeamPlayer } from './team-player.entity';
import { AuctionSession } from './auction-session.entity';
import { AuctionPlayerPool } from './auction-player-pool.entity';
import { AuctionBid } from './auction-bid.entity';
import { PurseLedger } from './purse-ledger.entity';
import { TournamentApplication } from './tournament-application.entity';
import { Match } from './match.entity';
import { MatchLineup } from './match-lineup.entity';
import { Coach } from './coach.entity';
import { PracticeSession } from './practice-session.entity';
import { PracticeAttendance } from './practice-attendance.entity';
import { Innings } from './innings.entity';
import { Over } from './over.entity';
import { Ball } from './ball.entity';
import { Partnership } from './partnership.entity';
import { Venue } from './venue.entity';
import { VenueUnavailability } from './venue-unavailability.entity';
import { Official } from './official.entity';
import { Sponsor } from './sponsor.entity';
import { FinanceTransaction } from './finance-transaction.entity';
import { Post } from './post.entity';
import { Notification } from './notification.entity';

/**
 * Explicit list of entity classes (as opposed to `export *` above, which
 * also re-exports each entity's sibling enums) — this is what should be
 * passed to TypeORM's `entities` option in data-source.ts / app.module.ts.
 */
export const allEntities = [
  Organization,
  User,
  OrgMembership,
  RefreshToken,
  Tournament,
  TournamentGroup,
  Team,
  TournamentTeam,
  Player,
  TeamPlayer,
  AuctionSession,
  AuctionPlayerPool,
  AuctionBid,
  PurseLedger,
  TournamentApplication,
  Match,
  MatchLineup,
  Coach,
  PracticeSession,
  PracticeAttendance,
  Innings,
  Over,
  Ball,
  Partnership,
  Venue,
  VenueUnavailability,
  Official,
  Sponsor,
  FinanceTransaction,
  Notification,
  Post,
];
