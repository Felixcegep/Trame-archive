export interface IconChipProps {
  icon: string;
  /** "primary" | "secondary" | "accent" | "neutral" */ color?: string;
  /** "circle" (quick actions, 38px) or "rounded" (library rows, 34\u201342px, r12) */ shape?: "circle" | "rounded";
  size?: number;
  /** Use the opaque pale surface tint instead of the 12% alpha tint */ surface?: boolean;
  iconSize?: number; filled?: boolean; style?: React.CSSProperties;
}
export declare function IconChip(props: IconChipProps): JSX.Element;