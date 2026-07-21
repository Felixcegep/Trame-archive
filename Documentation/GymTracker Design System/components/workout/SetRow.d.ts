export interface SetRowProps {
  /** 1-based set number */ index: number;
  /** Column values matching the exercise\u2019s tracking type, e.g. [reps, weight] */ values?: Array<string | number>;
  /** "pending" | "current" | "completed" */ state?: "pending" | "current" | "completed";
  /** Footnote under the inputs. Effort wording depends on the exercise's tracking type: strength sets use RPE ("RPE 8 \u00b7 Could do 2 more reps"); stretches/mobility NEVER use RPE — use a felt-intensity scale instead ("Étirement modéré \u00b7 sans douleur", scale: léger / modéré / profond); cardio uses effort zones ("Zone 2 \u00b7 conversation facile") */ note?: string;
  /** Show the lock glyph on a completed set */ locked?: boolean;
  onToggle?: () => void; onChange?: (column: number, value: string) => void;
  style?: React.CSSProperties;
}
export declare function SetRow(props: SetRowProps): JSX.Element;