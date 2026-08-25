import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '../../../core/auth/authStore'
import { notificationsApi } from '../api/notificationsApi'

/** Polling unread-count badge — mirrors
 * apps/mobile/lib/features/notifications/presentation/notification_bell.dart
 * (no WebSocket push for notifications in Phase 1, same as mobile). */
export function NotificationBell() {
  const organizationId = useAuthStore((s) => s.activeOrgId)

  const { data: count } = useQuery({
    queryKey: ['notifications', 'unread-count', organizationId],
    queryFn: () => notificationsApi.unreadCount(organizationId!),
    enabled: !!organizationId,
    refetchInterval: 45_000,
  })

  return (
    <button
      type="button"
      className="relative rounded-full p-2 text-text-secondary transition hover:bg-page"
      aria-label="Notifications"
    >
      <span className="text-xl">🔔</span>
      {!!count && count > 0 && (
        <span className="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-live px-1 text-[10px] font-bold text-white">
          {count > 99 ? '99+' : count}
        </span>
      )}
    </button>
  )
}
