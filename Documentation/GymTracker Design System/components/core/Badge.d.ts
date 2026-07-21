export interface BadgeProps {
  /** "primary" | "secondary" | "accent" | "neutral" */ color?: string;
  /** "tint" pale surface fill \u00b7 "card" translucent card fill (used on tinted banners, e.g. Week 2) */ variant?: "tint" | "card";
  children?: React.ReactNode; style?: React.CSSProperties;
}
export declare function Badge(props: BadgeProps): JSX.Element;