import { addDays, isSameDay } from '../dateUtils'

const DAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

/**
 * Sun-Sat horizontal date strip, plain divs (no calendar package — mirrors
 * matches_tab.dart's `_WeekStrip`, which deliberately avoids pulling in a
 * Flutter calendar package for the same reason). Highlights `selectedDate`
 * — or today, when nothing is explicitly selected and today falls within
 * the displayed week — as a filled primary-color circle. Tapping a date
 * calls `onSelect` to actually filter the list below to that day (real
 * filtering, wired by the caller — see MatchesTab); tapping the already-
 * highlighted date again is the caller's job to treat as "clear" (mirrors
 * mobile's `_selectDate` toggle behavior).
 */
export function WeekStrip({
  weekStart,
  selectedDate,
  onSelect,
}: {
  weekStart: Date
  selectedDate: Date | null
  onSelect: (date: Date) => void
}) {
  const today = new Date()

  return (
    <div className="grid grid-cols-7 gap-1 px-1 py-2">
      {DAY_LABELS.map((label, i) => {
        const date = addDays(weekStart, i)
        const isToday = isSameDay(date, today)
        const isSelected = selectedDate != null && isSameDay(date, selectedDate)
        const highlighted = isSelected || (selectedDate == null && isToday)

        return (
          <button
            key={label}
            type="button"
            onClick={() => onSelect(date)}
            className="flex flex-col items-center gap-1.5 rounded-lg py-1 transition hover:bg-page"
          >
            <span className="text-[11px] font-semibold text-text-muted">{label}</span>
            <span
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold transition ${
                highlighted ? 'bg-primary text-white' : 'text-text-primary'
              }`}
            >
              {date.getDate()}
            </span>
          </button>
        )
      })}
    </div>
  )
}
