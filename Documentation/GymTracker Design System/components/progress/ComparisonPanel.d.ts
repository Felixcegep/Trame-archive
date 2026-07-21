export interface ComparisonPanelProps {
  /** e.g. "Program vs performed" */ title?: string;
  /** true = green "Met" badge, false = amber "Missed" */ met?: boolean;
  planned: string;
  performed: string;
  suggested?: string;
  /** short chip labels, e.g. ["Sets: Met","Reps: Met"] */ checks?: string[];
  style?: React.CSSProperties;
}
/** Green-tinted planned-vs-performed panel (Save review, History detail). Never colors performed truth without this explicit comparison context. */
export declare function ComparisonPanel(props: ComparisonPanelProps): JSX.Element;
