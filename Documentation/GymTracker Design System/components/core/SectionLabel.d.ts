export interface SectionLabelProps {
  children: React.ReactNode;
  /** Optional leading icon + its color */ icon?: string; iconColor?: string;
  /** Muted inline detail after the label ("After preparation") */ detail?: React.ReactNode;
  /** Right-aligned action (e.g. an Add text button) */ trailing?: React.ReactNode;
  color?: string; style?: React.CSSProperties;
}
export declare function SectionLabel(props: SectionLabelProps): JSX.Element;