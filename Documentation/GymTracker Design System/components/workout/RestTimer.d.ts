export interface RestTimerProps {
  /** "running" | "paused" | "ready" */ state?: "running" | "paused" | "ready";
  /** "1:07" (tabular digits) */ remaining?: string;
  onAddTime?: (seconds: number) => void; onPauseResume?: () => void;
  onSkip?: () => void; onContinue?: () => void; style?: React.CSSProperties;
}
export declare function RestTimer(props: RestTimerProps): JSX.Element;