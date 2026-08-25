import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PlayerRankingsQueryDto } from '../players/dto/player-rankings-query.dto';
import { PlayersService } from '../players/players.service';

/**
 * The Player Rankings feature landed in this codebase during this module's
 * build (PlayersService.getRankings, backed by PlayerRankingsQueryDto) —
 * reused here verbatim, exactly per the task's "if it has landed, reuse the
 * rankings endpoint's service logic internally" instruction. No fallback
 * needed.
 *
 * `getRankings`'s response (`PlayerRankingRow`: position, playerId,
 * playerName, matchesPlayed, runs, wickets, average, economy) is already
 * public-safe as-is — no phone/email/documents/basePrice, just performance
 * figures and a name (player names are intentionally public in a fan-facing
 * cricket app) — so it's returned unmodified, unlike the other public
 * endpoints in this module which map/strip fields.
 */
@ApiTags('public')
@Controller('public/organizations/:organizationId/players')
export class PublicPlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get('rankings')
  @ApiOperation({
    summary:
      '[Public] Org-wide player leaderboard by runs/wickets/average/economy — reuses PlayersService.getRankings verbatim',
  })
  getRankings(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Query() query: PlayerRankingsQueryDto,
  ) {
    return this.playersService.getRankings(organizationId, query.metric, query.limit);
  }
}
