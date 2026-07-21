export interface SearchFieldProps {
  value?: string; onChange?: (value: string) => void;
  placeholder?: string; style?: React.CSSProperties;
}
export declare function SearchField(props: SearchFieldProps): JSX.Element;