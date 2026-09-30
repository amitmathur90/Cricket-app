import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tournament } from '../../database/entities/tournament.entity';
import { PUBLIC_TOURNAMENT_SELECT } from './public-tournaments.controller';

/**
 * Cross-org tournament discovery — the missing link the rest of the
 * `public/` module doesn't provide: every other controller here requires
 * already knowing an `organizationId` (see PublicModule's doc comment: "no
 * public 'discover organizations' flow yet"). This is the one exception,
 * deliberately kept in its own file/route (`public/tournaments`, no
 * `:organizationId` prefix) rather than added to
 * PublicTournamentsController, whose class-level route already assumes one.
 *
 * Same "fully unauthenticated, no guard, by design" invariant as the rest of
 * this module — see PublicModule's doc comment for why that's safe here.
 */
@ApiTags('public')
@Controller('public/tournaments')
export class PublicDiscoveryController {
  constructor(
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
  ) {}

  @Get()
  @ApiOperation({
    summary:
      '[Public] Discover tournaments across every organization — same column allow-list as ' +
      'PublicTournamentsController, plus the organization id/name so the client can link into ' +
      'GET public/organizations/:organizationId/tournaments/:tournamentId. Every tournament is ' +
      'public by default from the moment it is created (including still-`draft` ones — there is ' +
      'no separate "publish" step in the product flow), except the hidden per-org Quick Match pool.',
  })
  async findAll() {
    const tournaments = await this.tournamentRepo.find({
      select: { ...PUBLIC_TOURNAMENT_SELECT, organization: { id: true, name: true } },
      relations: ['organization'],
      where: { isQuickMatchPool: false },
      order: { startDate: 'DESC' },
    });
    return tournaments.map((t) => ({
      ...t,
      organizationId: t.organization.id,
      organizationName: t.organization.name,
      organization: undefined,
    }));
  }
}
