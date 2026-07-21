export interface SessionHeaderProps {
  title?: string;
  /** Elapsed time "0:50" (tabular) */ elapsed?: string;
  completedSets?: number; totalSets?: number;
  /** "1 exercise" */ exercises?: string;
  style?: React.CSSProperties;
}
export declare function SessionHeader(props: SessionHeaderProps): JSX.Element;