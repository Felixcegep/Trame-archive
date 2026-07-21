export interface UpcomingCalendarDay {
  /** Weekday label, e.g. "Lun" */ label: string;
  /** Day of month */ date: number | string;
  /** Planned workout name — renders a blue chip; keep it short ("Push", "Legs") */ workout?: string;
  /** Past day already trained — renders a sage check */ done?: boolean;
  isToday?: boolean;
}
export interface UpcomingCalendarProps {
  /** Usually 7 days starting today or Monday */ days?: UpcomingCalendarDay[];
  onSelect?: (index: number) => void;
  style?: React.CSSProperties;
}
/** Week strip showing the next planned workouts. Today = solid blue pill; planned days = blue 12% tint. */
export declare function UpcomingCalendar(props: UpcomingCalendarProps): JSX.Element;
