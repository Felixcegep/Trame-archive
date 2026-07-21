/** @startingPoint section="Lists" subtitle="Library / quick-action row with tinted icon chip" viewport="700x230" */
export interface ListRowProps {
  /** Leading semantic icon in a tinted chip */ icon?: string;
  /** Chip accent: "primary" | "secondary" | "accent" | "neutral" */ color?: string;
  /** Opaque pale surface behind the chip (library style). Default true */ surface?: boolean;
  title: React.ReactNode; subtitle?: React.ReactNode;
  /** Trailing muted count (Library categories) */ count?: number;
  trailing?: React.ReactNode; chevron?: boolean;
  /** Wrap in a card (default). false = plain row inside a grouped list */ card?: boolean;
  size?: number; onClick?: () => void; style?: React.CSSProperties;
}
export declare function ListRow(props: ListRowProps): JSX.Element;