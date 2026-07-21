export interface SetInputProps {
  value?: string | number; onChange?: (value: string) => void;
  width?: string; disabled?: boolean; style?: React.CSSProperties;
}
export declare function SetInput(props: SetInputProps): JSX.Element;