/** @startingPoint section="Workout" subtitle="Expandable exercise entry with set table" viewport="700x420" */
export interface ExerciseCardProps {
  name: string;
  /** "current" expanded blue \u00b7 "completed" green collapsed \u00b7 "collapsed" neutral */
  state?: "current" | "completed" | "collapsed";
  /** Column headers matching the tracking type. Default ["Reps","Weight (kg)"] */ columns?: string[];
  /** Blue prescription line. Strength: "3 \u00d7 8-10 \u00b7 RPE 8". Stretch/mobility (no RPE): "3 \u00d7 45 s \u00b7 étirement modéré" with columns ["Durée (s)","Intensité"]. Cardio: "20 min \u00b7 Zone 2" */ prescription?: string;
  /** Muted "Last time: 3 \u00d7 8 @ 50 kg \u00b7 Jul 12" */ lastTime?: string;
  completedSets?: number; totalSets?: number;
  /** Per-exercise elapsed "0:03" */ elapsed?: string;
  /** SetRow children (rendered only when current) */ children?: React.ReactNode;
  onAddSet?: () => void; onClick?: () => void; style?: React.CSSProperties;
}
export declare function ExerciseCard(props: ExerciseCardProps): JSX.Element;