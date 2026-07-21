export interface RecommendationCardProps {
  /** Exercise name, e.g. "Bench Press" */ exercise: string;
  /** Plain-language explanation sentence (never a bare number) */ rationale: string;
  /** Accept button label, e.g. "Accept 52.5 kg" */ acceptLabel: string;
  /** Keep button label, e.g. "Keep 50 kg" */ keepLabel: string;
  onAccept?: () => void;
  onKeep?: () => void;
  onEdit?: () => void;
  style?: React.CSSProperties;
}
/** Progression recommendation card (Screenshots/progression/10_Previous_Performance). White card, blue trend eyebrow, exercise title, plain-language rationale, filled-blue Accept + pale-blue Keep side by side, "Edit manually" text button. Recommendations are suggestions — copy must stay non-coercive. */
export declare function RecommendationCard(props: RecommendationCardProps): JSX.Element;
