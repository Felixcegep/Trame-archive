export interface ActivityHeatmapProps {
  /** 7-value columns (Mon-first), one per week; each value is an intensity level 0-4 (0 = rest, 4 = most volume) */ weeks?: number[][];
  /** Month labels positioned by week index, e.g. [{week:0,label:"Jan"},{week:4,label:"Fév"}] */ monthLabels?: Array<{week:number; label:string}>;
  /** Card heading, e.g. "127 séances cette année" */ title?: string;
  /** Muted note next to the title */ subtitle?: string;
  /** Cell size in px. Default 11 */ cell?: number;
  /** Gap between cells in px. Default 3 */ gap?: number;
  /** Show the Moins→Plus legend. Default true */ legend?: boolean;
  style?: React.CSSProperties;
}
/** GitHub-style training consistency heatmap. Green = sage success color (--gym-secondary), never the raw GitHub green. Level ≈ sets or sessions that day. */
export declare function ActivityHeatmap(props: ActivityHeatmapProps): JSX.Element;
