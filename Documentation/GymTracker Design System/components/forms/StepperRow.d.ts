export interface StepperRowProps {
  label: string;
  /** stepper: −/+ pill · picker: value + unfold chevron · toggle: iOS switch */ variant?: "stepper"|"picker"|"toggle";
  /** Shown inline in the label for stepper (e.g. "Sets: 3" → pass label already composed) or as the right value for picker */ value?: string|number;
  on?: boolean;
  onIncrement?: () => void;
  onDecrement?: () => void;
  onToggle?: (v: boolean) => void;
  onPress?: () => void;
  /** Hide the bottom hairline (last row in a group) */ last?: boolean;
  style?: React.CSSProperties;
}
/** Form-sheet row on the iOS systemGrouped surface (Screenshots/templates/12_Template_Progression, plans/13d). Three variants: stepper (gray −|+ segmented pill), picker (right-aligned value + unfold chevron), toggle (green iOS switch). Group several inside a white rounded card; hairline divider between rows. */
export declare function StepperRow(props: StepperRowProps): JSX.Element;
