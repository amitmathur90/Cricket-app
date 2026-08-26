import { NavLink, useNavigate } from 'react-router-dom'
import type { OrgRole } from '../../types/organization'
import { RoleGate } from '../../core/router/RoleGate'
import { useTournaments } from '../../features/tournaments/hooks/useTournaments'

interface NavItem {
  label: string
  icon: string
  path?: string
  minRole?: OrgRole
}

/** Direct translation of admin_drawer.dart's wired-item list (Phase 1
 * subset only) plus its "Soon" set, for expectation-setting parity with
 * the mobile app. See the plan addendum for what's deferred and why. */
const LIVE_ITEMS: NavItem[] = [
  { label: 'Dashboard', icon: '🏠', path: '/dashboard' },
  { label: 'Tournaments', icon: '🏆', path: '/tournaments' },
  { label: 'Players', icon: '🧑‍🤝‍🧑', path: '/players', minRole: 'tournament_admin' },
  { label: 'Matches / Schedule', icon: '📅', path: '/matches' },
]

const SOON_ITEMS: NavItem[] = [
  { label: 'Player Registration', icon: '📝' },
  { label: 'Captains', icon: '👤' },
  { label: 'Practice', icon: '🏋️' },
  { label: 'Live Score', icon: '📡' },
  { label: 'Statistics', icon: '📊' },
  { label: 'Venues', icon: '📍' },
  { label: 'Officials', icon: '🧑‍⚖️' },
  { label: 'Sponsors', icon: '🤝' },
  { label: 'Finance', icon: '💰' },
  { label: 'Awards', icon: '🏅' },
  { label: 'Reports', icon: '🗂️' },
  { label: 'Settings', icon: '⚙️' },
]

function NavRow({ item }: { item: NavItem }) {
  if (!item.path) {
    return (
      <div className="flex cursor-not-allowed items-center justify-between rounded-xl px-3 py-2.5 text-sm text-white/35">
        <span className="flex items-center gap-3">
          <span className="w-5 text-center">{item.icon}</span>
          {item.label}
        </span>
        <span className="rounded-full bg-white/10 px-2 py-0.5 text-[10px]">Soon</span>
      </div>
    )
  }

  const row = (
    <NavLink
      to={item.path}
      className={({ isActive }) =>
        `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
          isActive ? 'bg-primary text-white' : 'text-white/70 hover:bg-white/5 hover:text-white'
        }`
      }
    >
      <span className="w-5 text-center">{item.icon}</span>
      {item.label}
    </NavLink>
  )

  return item.minRole ? <RoleGate minRole={item.minRole}>{row}</RoleGate> : row
}

/** Sessions are tournament-scoped with no single global URL — mirrors
 * admin_drawer.dart's "jump directly only when there's exactly one
 * (auction-enabled) tournament, else land on the tournament list" pattern
 * rather than a plain static link. */
function AuctionNavRow() {
  const navigate = useNavigate()
  const { data: tournaments } = useTournaments()
  const auctionTournaments = (tournaments ?? []).filter((t) => t.auctionEnabled)

  function handleClick() {
    if (auctionTournaments.length === 1) {
      navigate(`/tournaments/${auctionTournaments[0].id}/auction`)
    } else {
      navigate('/tournaments')
    }
  }

  const row = (
    <button
      type="button"
      onClick={handleClick}
      className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium text-white/70 transition hover:bg-white/5 hover:text-white"
    >
      <span className="w-5 text-center">🔨</span>
      Auction
    </button>
  )

  return <RoleGate minRole="tournament_admin">{row}</RoleGate>
}

export function Sidebar() {
  return (
    <aside className="flex h-screen w-64 shrink-0 flex-col bg-navy px-3 py-5">
      <div className="mb-6 flex items-center gap-2 px-2">
        <span className="text-2xl">🏏</span>
        <span className="text-lg font-bold text-white">CricLeague</span>
      </div>

      <nav className="flex flex-1 flex-col gap-1 overflow-y-auto">
        {LIVE_ITEMS.map((item) => (
          <NavRow key={item.label} item={item} />
        ))}
        <AuctionNavRow />
        <div className="my-3 h-px bg-white/10" />
        {SOON_ITEMS.map((item) => (
          <NavRow key={item.label} item={item} />
        ))}
      </nav>
    </aside>
  )
}
