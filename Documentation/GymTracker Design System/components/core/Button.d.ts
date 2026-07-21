/** @startingPoint section="Core" subtitle="Capsule CTA, prominent bar, tinted and text buttons" viewport="700x260" */
export interface ButtonProps {
  /** "primary" capsule CTA (Start workout) \u00b7 "prominent" full-width r18 bar (Review Workout) \u00b7 "bordered" tinted (+15s) \u00b7 "text" borderless (Add set) */
  variant?: "primary" | "prominent" | "bordered" | "text";
  /** Accent: "primary" | "secondary" | "accent" | "destructive" (or any CSS color) */
  color?: string;
  /** Leading / trailing semantic icon names */ icon?: string; trailingIcon?: string;
  fullWidth?: boolean; disabled?: boolean; onClick?: () => void;
  children?: React.ReactNode; style?: React.CSSProperties;
}
export declare function Button(props: ButtonProps): JSX.Element;