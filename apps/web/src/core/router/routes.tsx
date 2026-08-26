import { Routes, Route } from 'react-router-dom'
import { AuthGate } from './AuthGate'
import { LoginPage } from '../../features/auth/pages/LoginPage'
import { OrgSelectPage } from '../../features/auth/pages/OrgSelectPage'
import { CreateOrganizationPage } from '../../features/organizations/pages/CreateOrganizationPage'
import { PageShell } from '../../shared/components/PageShell'
import { DashboardPage } from '../../features/dashboard/DashboardPage'
import { TournamentListPage } from '../../features/tournaments/pages/TournamentListPage'
import { TournamentCreatePage } from '../../features/tournaments/pages/TournamentCreatePage'
import { TournamentDetailPage } from '../../features/tournaments/pages/TournamentDetailPage'
import { TeamDetailPage } from '../../features/teams/pages/TeamDetailPage'
import { PlayerListPage } from '../../features/players/pages/PlayerListPage'
import { PlayerDetailPage } from '../../features/players/pages/PlayerDetailPage'
import { MatchListPage } from '../../features/matches/pages/MatchListPage'
import { MatchDetailPage } from '../../features/matches/pages/MatchDetailPage'
import { MatchFormPage } from '../../features/matches/pages/MatchFormPage'
import { AuctionSessionListPage } from '../../features/auction/pages/AuctionSessionListPage'
import { AuctionPoolPage } from '../../features/auction/pages/AuctionPoolPage'
import { LiveAuctionRoomPage } from '../../features/auction/pages/LiveAuctionRoomPage'

export function AppRoutes() {
  return (
    <AuthGate>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/select-org" element={<OrgSelectPage />} />
        <Route path="/create-organization" element={<CreateOrganizationPage />} />

        <Route element={<PageShell />}>
          <Route path="/dashboard" element={<DashboardPage />} />

          <Route path="/tournaments" element={<TournamentListPage />} />
          <Route path="/tournaments/create" element={<TournamentCreatePage />} />
          <Route path="/tournaments/:tournamentId" element={<TournamentDetailPage />} />
          <Route path="/tournaments/:tournamentId/teams/:teamId" element={<TeamDetailPage />} />
          <Route path="/tournaments/:tournamentId/matches/create" element={<MatchFormPage />} />
          <Route path="/tournaments/:tournamentId/matches/:matchId" element={<MatchDetailPage />} />
          <Route path="/tournaments/:tournamentId/matches/:matchId/edit" element={<MatchFormPage />} />

          <Route path="/tournaments/:tournamentId/auction" element={<AuctionSessionListPage />} />
          <Route path="/tournaments/:tournamentId/auction/:sessionId/pool" element={<AuctionPoolPage />} />
          <Route path="/tournaments/:tournamentId/auction/:sessionId" element={<LiveAuctionRoomPage />} />

          <Route path="/players" element={<PlayerListPage />} />
          <Route path="/players/:playerId" element={<PlayerDetailPage />} />

          <Route path="/matches" element={<MatchListPage />} />

          <Route path="*" element={<DashboardPage />} />
        </Route>
      </Routes>
    </AuthGate>
  )
}
