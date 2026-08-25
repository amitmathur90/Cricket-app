/** Date helpers shared by WeekStrip/MatchesTab — deliberately plain
 * Date-object arithmetic, no date library (see WeekStrip's doc comment for
 * why: mirrors matches_tab.dart's own no-new-package week strip). */

export function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

/** Midnight on the Sunday on/before `date` (JS `getDay()` is Sun=0..Sat=6). */
export function startOfWeek(date: Date): Date {
  const day = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  day.setDate(day.getDate() - day.getDay())
  return day
}

export function addDays(date: Date, days: number): Date {
  const result = new Date(date)
  result.setDate(result.getDate() + days)
  return result
}

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

const GROUP_DATE_FORMAT = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'long', year: 'numeric' })
const WEEK_STRIP_MONTH_FORMAT = new Intl.DateTimeFormat(undefined, { month: 'long', year: 'numeric' })
const TIME_FORMAT = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' })

export function formatGroupDate(date: Date): string {
  return GROUP_DATE_FORMAT.format(date)
}

export function formatMonthLabel(date: Date): string {
  return WEEK_STRIP_MONTH_FORMAT.format(date)
}

export function formatTime(date: Date): string {
  return TIME_FORMAT.format(date)
}
