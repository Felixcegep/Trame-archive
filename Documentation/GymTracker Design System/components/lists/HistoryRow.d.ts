export interface HistoryRowProps {
  title: string;
  /** "Today, 5:11 PM" or "Jul 12, 2026" */ date?: string;
  /** "59 min" */ duration?: string;
  /** "1 exercise" */ exercises?: string;
  /** "3 sets" */ sets?: string;
  /** Source template/plan name \u2014 renders "From \u2026" in tan */ source?: string;
  onClick?: () => void; style?: React.CSSProperties;
}
export declare function HistoryRow(props: HistoryRowProps): JSX.Element;