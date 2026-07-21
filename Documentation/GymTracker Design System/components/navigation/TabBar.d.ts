export interface TabBarTab { key: string; icon: string; label: string; }
export interface TabBarProps {
  /** Defaults to Home / Library / History / Settings */ tabs?: TabBarTab[];
  active?: string; onChange?: (key: string) => void; style?: React.CSSProperties;
}
export declare function TabBar(props: TabBarProps): JSX.Element;