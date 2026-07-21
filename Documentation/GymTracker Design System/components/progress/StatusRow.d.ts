export interface StatusRowProps {
  title: string;
  detail?: string;
  /** completed | skipped | missed | in-progress | ready | scheduled */ status: "completed"|"skipped"|"missed"|"in-progress"|"ready"|"scheduled";
  /** Highlight as today */ isToday?: boolean;
  style?: React.CSSProperties;
}
/** Calendar/schedule day row with the app's exact status vocabulary (Screenshots/plans/13e_Plan_Calendar). completed=green check, skipped=gray dashed circle, missed=red warning, in-progress=blue dumbbell, ready=blue dot, scheduled=empty outline. */
export declare function StatusRow(props: StatusRowProps): JSX.Element;
