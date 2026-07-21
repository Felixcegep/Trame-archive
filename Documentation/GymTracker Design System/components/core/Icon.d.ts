/** Semantic icon (SF Symbols substituted with Material Symbols Rounded on the web). */
export interface IconProps {
  /** Semantic name mirroring AppIcon in Icons.swift (e.g. "workout", "timer", "checkmarkCircle") or a raw Material Symbols glyph name */
  name: string;
  /** px size. Default 20 */ size?: number;
  /** Filled style (default true, matching the app\u2019s .fill symbols) */ filled?: boolean;
  /** Variable-font weight 300\u2013700. Default 500 */ weight?: number;
  color?: string; style?: React.CSSProperties; className?: string;
}
export declare function Icon(props: IconProps): JSX.Element;