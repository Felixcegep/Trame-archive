export interface SegmentedControlProps {
  /** Strings or {value,label} pairs */ options: Array<string | {value: string; label: string}>;
  value: string; onChange?: (value: string) => void; style?: React.CSSProperties;
}
export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;