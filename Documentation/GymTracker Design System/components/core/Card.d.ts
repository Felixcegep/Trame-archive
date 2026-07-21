/** @startingPoint section="Core" subtitle="Warm-white card with hairline border and whisper shadow" viewport="700x220" */
export interface CardProps {
  /** standard | elevated | outlined (blue 16% ring, idle primary card) | current (blue-gray) | completed (green-gray) | accent (tan) | muted */
  variant?: "standard" | "elevated" | "outlined" | "current" | "completed" | "accent" | "muted";
  /** card 20 | section 18 | large 16 (or any CSS radius) */ radius?: "card" | "section" | "large" | string;
  padding?: string;
  /** Renders as a pressable button with the 0.97-scale press effect */ onClick?: () => void;
  children?: React.ReactNode; style?: React.CSSProperties;
}
export declare function Card(props: CardProps): JSX.Element;